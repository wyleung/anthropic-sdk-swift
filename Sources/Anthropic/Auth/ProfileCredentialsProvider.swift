import Foundation

/// `CredentialProvider` for an on-disk `user_oauth` profile: reads `credentials/<profile>.json`,
/// refreshes via the `refresh_token` grant when needed, and persists the (possibly rotated) refresh
/// token back to disk. Emits `anthropic-workspace-id` when the profile has a workspace scope --
/// unlike `WorkloadIdentityCredentials`, which never does.
///
/// The provider closure handed to `TokenCache` re-reads the credentials file on every
/// mandatory/advisory refresh (not just on first use), so a token another process already rotated
/// on disk is picked up instead of triggering a redundant network refresh. Once a token is loaded
/// into the in-process `TokenCache`, though, calls within the >120s advisory window are served from
/// memory without touching disk again -- matching the reference SDKs' choice to trade a small window
/// of cross-process staleness for not re-reading the file on every single request.
final class ProfileCredentialsProvider: CredentialProvider {
    private let profile: String
    private let environment: [String: String]
    private let clientId: String
    private let workspaceId: String?
    private let baseURL: URL
    private let urlSession: URLSession
    private let cache = TokenCache()

    init(
        profile: String,
        environment: [String: String],
        clientId: String,
        workspaceId: String?,
        baseURL: URL,
        urlSession: URLSession
    ) {
        self.profile = profile
        self.environment = environment
        self.clientId = clientId
        self.workspaceId = workspaceId
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func authHeader() async throws -> (name: String, value: String) {
        let token = try await cache.token { _ in try await self.refreshOrLoad() }
        return ("authorization", "Bearer \(token.accessToken)")
    }

    func extraHeaders() async throws -> [String: String] {
        var headers = ["anthropic-beta": OAuthTokenEndpoint.oauthBetaHeader]
        if let workspaceId { headers["anthropic-workspace-id"] = workspaceId }
        return headers
    }

    func invalidate() async {
        await cache.invalidate()
    }

    private func refreshOrLoad() async throws -> AccessToken {
        guard let stored = try CredentialsStore.read(profile: profile, environment: environment) else {
            throw AnthropicError.responseValidation(
                message: "No stored credentials found for profile \"\(profile)\".", body: nil
            )
        }
        if stored.expiresAt == nil || stored.expiresAt!.timeIntervalSinceNow > 30 {
            return AccessToken(
                accessToken: stored.accessToken, expiresAt: stored.expiresAt, refreshToken: stored.refreshToken
            )
        }

        guard let refreshToken = stored.refreshToken else {
            throw AnthropicError.responseValidation(
                message: "Stored credentials for profile \"\(profile)\" are expired and have no refresh_token.",
                body: nil
            )
        }
        let refreshed = try await OAuthTokenEndpoint.exchangeRefreshToken(
            baseURL: baseURL, refreshToken: refreshToken, clientId: clientId, urlSession: urlSession
        )
        try CredentialsStore.store(
            profile: profile, environment: environment, accessToken: refreshed.accessToken,
            expiresAt: refreshed.expiresAt, refreshToken: refreshed.refreshToken
        )
        return refreshed
    }
}
