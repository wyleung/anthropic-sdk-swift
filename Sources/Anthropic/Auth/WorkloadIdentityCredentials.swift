import Foundation

/// `CredentialProvider` for Workload Identity Federation (`authentication.type == "oidc_federation"`).
/// Exchanges a caller-supplied identity token for a short-lived Bearer access token via
/// `POST {baseURL}/v1/oauth/token` (`jwt-bearer` grant), caching/refreshing it through a
/// `TokenCache`. Never emits `anthropic-workspace-id` -- that header is `user_oauth`-only.
final class WorkloadIdentityCredentials: CredentialProvider {
    private let baseURL: URL
    private let federationRuleId: String
    private let organizationId: String
    private let serviceAccountId: String?
    private let workspaceId: String?
    private let identityTokenSource: any IdentityTokenSource
    private let urlSession: URLSession
    private let cache = TokenCache()

    init(
        baseURL: URL,
        federationRuleId: String,
        organizationId: String,
        serviceAccountId: String?,
        workspaceId: String?,
        identityTokenSource: any IdentityTokenSource,
        urlSession: URLSession
    ) {
        self.baseURL = baseURL
        self.federationRuleId = federationRuleId
        self.organizationId = organizationId
        self.serviceAccountId = serviceAccountId
        self.workspaceId = workspaceId
        self.identityTokenSource = identityTokenSource
        self.urlSession = urlSession
    }

    func authHeader() async throws -> (name: String, value: String) {
        let token = try await cache.token { _ in
            let assertion = try await self.identityTokenSource.token()
            return try await OAuthTokenEndpoint.exchangeJWTBearer(
                baseURL: self.baseURL,
                assertion: assertion,
                federationRuleId: self.federationRuleId,
                organizationId: self.organizationId,
                serviceAccountId: self.serviceAccountId,
                workspaceId: self.workspaceId,
                urlSession: self.urlSession
            )
        }
        return ("authorization", "Bearer \(token.accessToken)")
    }

    func extraHeaders() async throws -> [String: String] {
        ["anthropic-beta": OAuthTokenEndpoint.oauthBetaHeader]
    }

    func invalidate() async {
        await cache.invalidate()
    }
}
