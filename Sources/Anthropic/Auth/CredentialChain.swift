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

/// Implements the reference SDKs' credential-resolution precedence (Python's `_client.py` /
/// `default_credentials`, TypeScript's `credential-chain.ts`), first match wins:
///
/// 1. An explicit argument: `authProvider`, `apiKey` or `profile`. **At most one** may be passed
///    (otherwise ``AnthropicError/invalidArgument(message:)``), and when one is the environment is not
///    consulted for credentials. An explicit profile that cannot be loaded is a hard error.
/// 2. `ANTHROPIC_API_KEY`, then `ANTHROPIC_AUTH_TOKEN`.
/// 3. `ANTHROPIC_PROFILE`: load the profile it names. A broken one is a hard error -- the caller asked
///    for it by name.
/// 4. Workload Identity Federation via pure env vars (`ANTHROPIC_FEDERATION_RULE_ID` +
///    `ANTHROPIC_ORGANIZATION_ID` + an identity token source) -- bypasses config files entirely, and
///    ranks above the active profile so a machine with WIF wired up is not hijacked by a leftover
///    profile on disk.
/// 5. The active profile: the one `active_config` points at, otherwise `default`.
///    `ANTHROPIC_CONFIG_DIR` says where profiles are looked up and selects none. If the user set it or
///    wrote the `active_config` pointer, a broken profile is a hard error; a profile found only by
///    passive discovery is best-effort, and its failures are swallowed.
/// 6. Nothing matched: throw ``AnthropicError/credentials(message:)``.
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
        try requireAtMostOneExplicitCredential(apiKey: apiKey, authProvider: authProvider, profile: profile)

        if let authProvider {
            return CredentialResolution(provider: authProvider, baseURL: nil)
        }
        if let apiKey {
            return CredentialResolution(provider: APIKeyProvider(apiKey: apiKey), baseURL: nil)
        }
        if let profile {
            return try await loadProfile(
                try ProfilePaths.validateProfileName(profile), baseURL: baseURL, environment: environment,
                urlSession: urlSession, identityTokenSourceOverride: identityTokenSource
            )
        }

        if let envKey = nonEmpty(environment["ANTHROPIC_API_KEY"]) {
            return CredentialResolution(provider: APIKeyProvider(apiKey: envKey), baseURL: nil)
        }
        if let envToken = nonEmpty(environment["ANTHROPIC_AUTH_TOKEN"]) {
            return CredentialResolution(provider: StaticTokenProvider(token: envToken), baseURL: nil)
        }

        if let envProfile = nonEmpty(environment["ANTHROPIC_PROFILE"]) {
            return try await loadProfile(
                try ProfilePaths.validateProfileName(envProfile), baseURL: baseURL, environment: environment,
                urlSession: urlSession, identityTokenSourceOverride: identityTokenSource
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

        if ProfilePaths.isActiveProfileUserConfigured(environment: environment) {
            return try await loadProfile(
                try ProfilePaths.activeProfile(environment: environment), baseURL: baseURL,
                environment: environment, urlSession: urlSession, identityTokenSourceOverride: identityTokenSource
            )
        }
        if let passiveProfile = try? ProfilePaths.activeProfile(environment: environment),
            let resolution = try? await loadProfile(
                passiveProfile, baseURL: baseURL, environment: environment, urlSession: urlSession,
                identityTokenSourceOverride: identityTokenSource
            ) {
            return resolution
        }

        throw AnthropicError.credentials(
            message: "Could not resolve Anthropic credentials. Pass an apiKey/authProvider/profile, set " +
                "ANTHROPIC_API_KEY, or configure a profile under \(ProfilePaths.configDirectory(environment: environment).path)."
        )
    }

    /// A client has one credential. Passing two of `apiKey` / `authProvider` / `profile` used to be
    /// resolved silently by precedence, which hid the mistake of leaving a stale one in place.
    static func requireAtMostOneExplicitCredential(
        apiKey: String?, authProvider: (any CredentialProvider)?, profile: String?
    ) throws {
        let passed = [
            apiKey != nil ? "apiKey" : nil,
            authProvider != nil ? "authProvider" : nil,
            profile != nil ? "profile" : nil,
        ].compactMap { $0 }
        guard passed.count > 1 else { return }
        throw AnthropicError.invalidArgument(
            message: "Pass at most one of `apiKey`, `authProvider`, or `profile`. Received \(passed.joined(separator: ", "))."
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
            throw AnthropicError.credentials(
                message: "No config file found for profile \"\(profileName)\"."
            )
        }
        let resolvedBaseURL = effectiveBaseURL(baseURL, environment: environment, configBaseURL: config.baseURL)
        let configBaseURLObject = config.baseURL.flatMap { URL(string: $0) }

        switch config.authentication.type {
        case .oidcFederation:
            // `federation_rule_id`/`organization_id` are deliberately validated here, not at
            // config-load time -- a `user_oauth` profile never needs either field.
            guard let federationRuleId = nonEmpty(config.authentication.federationRuleId) else {
                throw AnthropicError.credentials(
                    message: "Profile \"\(profileName)\" is missing federation_rule_id for oidc_federation."
                )
            }
            guard let organizationId = nonEmpty(config.organizationId) else {
                throw AnthropicError.credentials(
                    message: "Profile \"\(profileName)\" is missing organization_id for oidc_federation."
                )
            }
            guard let source = identityTokenSourceOverride
                ?? config.authentication.identityToken.map({ FileIdentityTokenSource(path: $0.path) }) else {
                throw AnthropicError.credentials(
                    message: "Profile \"\(profileName)\" has no identity token source configured."
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
                throw AnthropicError.credentials(
                    message: "Profile \"\(profileName)\" is missing client_id for user_oauth."
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
        if nonEmpty(environment["ANTHROPIC_IDENTITY_TOKEN"]) != nil {
            return EnvIdentityTokenSource(variableName: "ANTHROPIC_IDENTITY_TOKEN")
        }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
