/// Ported from `beta_managed_agents_mcp_oauth_create_params.py`. `mcpServerUrl` is immutable after
/// create (absent from the update params); `accessToken` is write-only (never returned by the
/// response type). `expiresAt` is a pre-formatted ISO8601 timestamp string.
public struct BetaManagedAgentsMCPOAuthCreateParams: Encodable, Sendable, Equatable {
    public var accessToken: String
    public var mcpServerUrl: String
    public var type = "mcp_oauth"
    public var expiresAt: String?
    public var refresh: BetaManagedAgentsMCPOAuthRefreshParams?

    public init(
        accessToken: String,
        mcpServerUrl: String,
        expiresAt: String? = nil,
        refresh: BetaManagedAgentsMCPOAuthRefreshParams? = nil
    ) {
        self.accessToken = accessToken
        self.mcpServerUrl = mcpServerUrl
        self.expiresAt = expiresAt
        self.refresh = refresh
    }
}

/// Ported from `beta_managed_agents_mcp_oauth_update_params.py`. `mcpServerUrl` is absent
/// (immutable).
public struct BetaManagedAgentsMCPOAuthUpdateParams: Encodable, Sendable, Equatable {
    public var type = "mcp_oauth"
    public var accessToken: String?
    public var expiresAt: String?
    public var refresh: BetaManagedAgentsMCPOAuthRefreshUpdateParams?

    public init(
        accessToken: String? = nil,
        expiresAt: String? = nil,
        refresh: BetaManagedAgentsMCPOAuthRefreshUpdateParams? = nil
    ) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.refresh = refresh
    }
}

/// Ported from `beta_managed_agents_mcp_oauth_auth_response.py`. No `accessToken` -- sensitive
/// fields are never returned in responses.
public struct BetaManagedAgentsMCPOAuthAuthResponse: Codable, Sendable, Equatable {
    public let mcpServerUrl: String
    public let type: String
    public let expiresAt: String?
    public let refresh: BetaManagedAgentsMCPOAuthRefreshResponse?

    public init(
        mcpServerUrl: String,
        type: String = "mcp_oauth",
        expiresAt: String? = nil,
        refresh: BetaManagedAgentsMCPOAuthRefreshResponse? = nil
    ) {
        self.mcpServerUrl = mcpServerUrl
        self.type = type
        self.expiresAt = expiresAt
        self.refresh = refresh
    }
}
