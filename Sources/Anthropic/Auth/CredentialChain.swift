import Foundation

/// A resolved credential provider plus the `base_url` (if any) that came along with it -- e.g. a
/// profile's own `configs/<profile>.json` `base_url` field. `AnthropicClient.resolvingCredentials`
/// combines this with its own explicit-param/env-var precedence via `??`, so this only needs to
/// carry the profile-sourced value; it's `nil` whenever the resolved credential didn't come from a
/// config file (steps 1/2/3/5 below).
struct CredentialResolution: Sendable {
    let provider: any CredentialProvider
    let baseURL: URL?
}

/// Implements the reference SDKs' full credential-resolution precedence (`_client.py`'s
/// `_resolve_credentials` / `credential-chain.ts`), in order, first match wins:
///
/// 1. An explicit `authProvider` passed to the client constructor.
/// 2. An explicit `apiKey` passed to the client constructor.
/// 3. `ANTHROPIC_API_KEY`, then `ANTHROPIC_AUTH_TOKEN` -- only when no `profile` was requested.
/// 4. Explicit profile selection (`profile` param, or `ANTHROPIC_PROFILE`/`ANTHROPIC_CONFIG_DIR` env,
///    or a non-empty `active_config` pointer file). Failures here are hard errors -- the caller asked
///    for a specific profile, so a broken one should not be silently skipped.
/// 5. Workload Identity Federation via pure env vars (`ANTHROPIC_FEDERATION_RULE_ID` +
///    `ANTHROPIC_ORGANIZATION_ID` + an identity token source) -- bypasses config files entirely.
/// 6. A fallback attempt to load whatever the *passively discovered* active profile would be (i.e.
///    `"default"` when nothing points elsewhere). Both the profile-name resolution and the load are
///    `try?` -- this step is a best-effort convenience, not a request the caller made explicitly, so
///    its failures are swallowed rather than raised.
/// 7. Nothing matched: throw a generic "could not resolve credentials" error.
enum CredentialChain {
    static func resolve(
        apiKey: String?,
        authProvider: (any CredentialProvider)?,
        profile: String?,
        baseURL: URL?,
        environment: [String: String],
        urlSession: URLSession,
        identityTokenSource: (any IdentityTokenSource)? = nil
    ) async throws -> CredentialResolution {
        if let authProvider {
            return CredentialResolution(provider: authProvider, baseURL: nil)
        }
        if let apiKey {
            return CredentialResolution(provider: APIKeyProvider(apiKey: apiKey), baseURL: nil)
        }
        if profile == nil {
            if let envKey = nonEmpty(environment["ANTHROPIC_API_KEY"]) {
                return CredentialResolution(provider: APIKeyProvider(apiKey: envKey), baseURL: nil)
            }
            if let envToken = nonEmpty(environment["ANTHROPIC_AUTH_TOKEN"]) {
                return CredentialResolution(provider: StaticTokenProvider(token: envToken), baseURL: nil)
            }
        }

        if profile != nil || ProfilePaths.hasExplicitActiveConfig(environment: environment) {
            let profileName = try profile.map(ProfilePaths.validateProfileName)
                ?? (try ProfilePaths.activeProfile(environment: environment))
            return try await loadProfile(
                profileName, baseURL: baseURL, environment: environment, urlSession: urlSession,
                identityTokenSourceOverride: identityTokenSource
            )
        }

        if let federationRuleId = nonEmpty(environment["ANTHROPIC_FEDERATION_RULE_ID"]),
            let organizationId = nonEmpty(environment["ANTHROPIC_ORGANIZATION_ID"]),
            let source = resolveEnvIdentityTokenSource(environment: environment, override: identityTokenSource) {
            let provider = WorkloadIdentityCredentials(
                baseURL: effectiveBaseURL(baseURL, environment: environment, configBaseURL: nil),
                federationRuleId: federationRuleId,
                organizationId: organizationId,
                serviceAccountId: nonEmpty(environment["ANTHROPIC_SERVICE_ACCOUNT_ID"]),
                workspaceId: nonEmpty(environment["ANTHROPIC_WORKSPACE_ID"]),
                identityTokenSource: source,
                urlSession: urlSession
            )
            return CredentialResolution(provider: provider, baseURL: nil)
        }

        if let fallbackProfile = try? ProfilePaths.activeProfile(environment: environment),
            let resolution = try? await loadProfile(
                fallbackProfile, baseURL: baseURL, environment: environment, urlSession: urlSession,
                identityTokenSourceOverride: identityTokenSource
            ) {
            return resolution
        }

        throw AnthropicError.responseValidation(
            message: "Could not resolve Anthropic credentials. Pass an apiKey/authProvider, set " +
                "ANTHROPIC_API_KEY, or configure a profile under \(ProfilePaths.configDirectory(environment: environment).path).",
            body: nil
        )
    }

    private static func loadProfile(
        _ profileName: String,
        baseURL: URL?,
        environment: [String: String],
        urlSession: URLSession,
        identityTokenSourceOverride: (any IdentityTokenSource)?
    ) async throws -> CredentialResolution {
        guard let config = try AnthropicConfigFile.load(profile: profileName, environment: environment) else {
            throw AnthropicError.responseValidation(
                message: "No config file found for profile \"\(profileName)\".", body: nil
            )
        }
        let resolvedBaseURL = effectiveBaseURL(baseURL, environment: environment, configBaseURL: config.baseURL)
        let configBaseURLObject = config.baseURL.flatMap { URL(string: $0) }

        switch config.authentication.type {
        case .oidcFederation:
            // `federation_rule_id`/`organization_id` are deliberately validated here, not at
            // config-load time -- a `user_oauth` profile never needs either field.
            guard let federationRuleId = nonEmpty(config.authentication.federationRuleId) else {
                throw AnthropicError.responseValidation(
                    message: "Profile \"\(profileName)\" is missing federation_rule_id for oidc_federation.",
                    body: nil
                )
            }
            guard let organizationId = nonEmpty(config.organizationId) else {
                throw AnthropicError.responseValidation(
                    message: "Profile \"\(profileName)\" is missing organization_id for oidc_federation.", body: nil
                )
            }
            guard let source = identityTokenSourceOverride
                ?? config.authentication.identityToken.map({ FileIdentityTokenSource(path: $0.path) }) else {
                throw AnthropicError.responseValidation(
                    message: "Profile \"\(profileName)\" has no identity token source configured.", body: nil
                )
            }
            let provider = WorkloadIdentityCredentials(
                baseURL: resolvedBaseURL,
                federationRuleId: federationRuleId,
                organizationId: organizationId,
                serviceAccountId: config.authentication.serviceAccountId,
                workspaceId: config.workspaceId,
                identityTokenSource: source,
                urlSession: urlSession
            )
            return CredentialResolution(provider: provider, baseURL: configBaseURLObject)

        case .userOAuth:
            guard let clientId = nonEmpty(config.authentication.clientId) else {
                throw AnthropicError.responseValidation(
                    message: "Profile \"\(profileName)\" is missing client_id for user_oauth.", body: nil
                )
            }
            let provider = ProfileCredentialsProvider(
                profile: profileName,
                environment: environment,
                clientId: clientId,
                workspaceId: config.workspaceId,
                baseURL: resolvedBaseURL,
                urlSession: urlSession
            )
            return CredentialResolution(provider: provider, baseURL: configBaseURLObject)
        }
    }

    private static func effectiveBaseURL(
        _ explicit: URL?, environment: [String: String], configBaseURL: String?
    ) -> URL {
        explicit
            ?? nonEmpty(environment["ANTHROPIC_BASE_URL"]).flatMap { URL(string: $0) }
            ?? configBaseURL.flatMap { URL(string: $0) }
            ?? AnthropicClient.defaultBaseURL
    }

    private static func resolveEnvIdentityTokenSource(
        environment: [String: String], override: (any IdentityTokenSource)?
    ) -> (any IdentityTokenSource)? {
        if let override { return override }
        if let path = nonEmpty(environment["ANTHROPIC_IDENTITY_TOKEN_FILE"]) {
            return FileIdentityTokenSource(path: path)
        }
        if environment["ANTHROPIC_IDENTITY_TOKEN"] != nil {
            return EnvIdentityTokenSource(variableName: "ANTHROPIC_IDENTITY_TOKEN")
        }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
