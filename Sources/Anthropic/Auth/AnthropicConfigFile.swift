import Foundation

/// Parses `configs/<profile>.json` -- non-secret profile configuration (as opposed to
/// `credentials/<profile>.json`, which holds the access/refresh tokens). Ported from the reference
/// SDKs' `_config.py` / `config-file.ts`.
///
/// Uses `JSONSerialization`/`[String: Any]` rather than `JSONDecoder` deliberately: `HTTPTransport`'s
/// decoder applies `.convertFromSnakeCase`, which would mangle literal keys like `federation_rule_id`
/// if this type were decoded as a `Codable` through that same decoder family.
struct AnthropicConfigFile: Sendable {
    enum AuthenticationType: String {
        case oidcFederation = "oidc_federation"
        case userOAuth = "user_oauth"
    }

    struct IdentityTokenConfig: Sendable {
        let source: String
        let path: String
    }

    struct Authentication: Sendable {
        var type: AuthenticationType
        var federationRuleId: String?
        var serviceAccountId: String?
        var scope: String?
        var identityToken: IdentityTokenConfig?
        var credentialsPath: String?
        var clientId: String?
    }

    var authentication: Authentication
    var organizationId: String?
    var workspaceId: String?
    var baseURL: String?

    /// Returns `nil` if no config file exists for `profile` -- that's a normal, expected state (the
    /// pure-env-var and WIF-env-var credential paths never touch disk), not an error.
    static func load(profile: String, environment: [String: String]) throws -> AnthropicConfigFile? {
        let path = try ProfilePaths.configFilePath(profile: profile, environment: environment)
        guard let data = try? Data(contentsOf: path) else { return nil }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AnthropicError.responseValidation(
                message: "Config file at \(path.path) is not a valid JSON object.", body: nil
            )
        }
        return try parse(object, environment: environment)
    }

    private static func parse(_ object: [String: Any], environment: [String: String]) throws -> AnthropicConfigFile {
        guard let authObject = object["authentication"] as? [String: Any] else {
            throw AnthropicError.responseValidation(message: "Config file is missing \"authentication\".", body: nil)
        }
        guard let typeString = authObject["type"] as? String, let type = AuthenticationType(rawValue: typeString) else {
            throw AnthropicError.responseValidation(
                message: "Config file has an unrecognized authentication.type.", body: nil
            )
        }

        // Env-var backfill: the file always wins, an env var only fills an empty/absent field.
        var federationRuleId = nonEmpty(authObject["federation_rule_id"] as? String)
        federationRuleId = federationRuleId ?? nonEmpty(environment["ANTHROPIC_FEDERATION_RULE_ID"])

        var organizationId = nonEmpty(object["organization_id"] as? String)
        organizationId = organizationId ?? nonEmpty(environment["ANTHROPIC_ORGANIZATION_ID"])

        var workspaceId = nonEmpty(object["workspace_id"] as? String)
        workspaceId = workspaceId ?? nonEmpty(environment["ANTHROPIC_WORKSPACE_ID"])

        var baseURLString = nonEmpty(object["base_url"] as? String)
        baseURLString = baseURLString ?? nonEmpty(environment["ANTHROPIC_BASE_URL"])
        if let baseURLString {
            try ProfilePaths.requireHTTPS(baseURLString)
        }

        // `identity_token` is only ever synthesized from the *_FILE env var, never from a literal
        // token value -- a literal `ANTHROPIC_IDENTITY_TOKEN` is only reachable via the pure-env-var
        // credential-chain step, not through a config-file profile.
        var identityToken: IdentityTokenConfig?
        if let identityObject = authObject["identity_token"] as? [String: Any],
            let source = identityObject["source"] as? String, source == "file",
            let path = nonEmpty(identityObject["path"] as? String) {
            identityToken = IdentityTokenConfig(source: source, path: path)
        } else if let envPath = nonEmpty(environment["ANTHROPIC_IDENTITY_TOKEN_FILE"]) {
            identityToken = IdentityTokenConfig(source: "file", path: envPath)
        }

        let authentication = Authentication(
            type: type,
            federationRuleId: federationRuleId,
            serviceAccountId: nonEmpty(authObject["service_account_id"] as? String),
            scope: nonEmpty(authObject["scope"] as? String),
            identityToken: identityToken,
            credentialsPath: nonEmpty(authObject["credentials_path"] as? String),
            clientId: nonEmpty(authObject["client_id"] as? String)
        )

        // `federation_rule_id`/`organization_id` presence is deliberately NOT validated here --
        // only lazily, when a WIF exchange is actually attempted. A `user_oauth` profile has no use
        // for either field and shouldn't be forced to fail config-load over their absence.
        return AnthropicConfigFile(
            authentication: authentication, organizationId: organizationId, workspaceId: workspaceId,
            baseURL: baseURLString
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
