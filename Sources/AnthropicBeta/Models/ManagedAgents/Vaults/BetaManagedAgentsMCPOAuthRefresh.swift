/// Ported from `beta_managed_agents_mcp_oauth_refresh_params.py`. Configures automatic refresh-token
/// exchange for an `mcp_oauth` credential.
public struct BetaManagedAgentsMCPOAuthRefreshParams: Encodable, Sendable, Equatable {
    public var clientId: String
    public var refreshToken: String
    public var tokenEndpoint: String
    public var tokenEndpointAuth: BetaManagedAgentsTokenEndpointAuthParam
    public var resource: String?
    public var scope: String?

    public init(
        clientId: String,
        refreshToken: String,
        tokenEndpoint: String,
        tokenEndpointAuth: BetaManagedAgentsTokenEndpointAuthParam,
        resource: String? = nil,
        scope: String? = nil
    ) {
        self.clientId = clientId
        self.refreshToken = refreshToken
        self.tokenEndpoint = tokenEndpoint
        self.tokenEndpointAuth = tokenEndpointAuth
        self.resource = resource
        self.scope = scope
    }
}

/// Ported from `beta_managed_agents_mcp_oauth_refresh_response.py`. `refreshToken` is write-only and
/// never returned.
public struct BetaManagedAgentsMCPOAuthRefreshResponse: Codable, Sendable, Equatable {
    public let clientId: String
    public let tokenEndpoint: String
    public let tokenEndpointAuth: BetaManagedAgentsTokenEndpointAuthResponse
    public let resource: String?
    public let scope: String?

    public init(
        clientId: String,
        tokenEndpoint: String,
        tokenEndpointAuth: BetaManagedAgentsTokenEndpointAuthResponse,
        resource: String? = nil,
        scope: String? = nil
    ) {
        self.clientId = clientId
        self.tokenEndpoint = tokenEndpoint
        self.tokenEndpointAuth = tokenEndpointAuth
        self.resource = resource
        self.scope = scope
    }
}

/// Ported from `beta_managed_agents_mcp_oauth_refresh_update_params.py`. Deliberately has fewer
/// fields than `BetaManagedAgentsMCPOAuthRefreshParams` -- `clientId`, `tokenEndpoint`, and `resource`
/// are immutable once a refresh is configured and have no update path at all (not merely optional).
public struct BetaManagedAgentsMCPOAuthRefreshUpdateParams: Encodable, Sendable, Equatable {
    public var refreshToken: String?
    public var scope: String?
    public var tokenEndpointAuth: BetaManagedAgentsTokenEndpointAuthUpdateParam?

    public init(
        refreshToken: String? = nil,
        scope: String? = nil,
        tokenEndpointAuth: BetaManagedAgentsTokenEndpointAuthUpdateParam? = nil
    ) {
        self.refreshToken = refreshToken
        self.scope = scope
        self.tokenEndpointAuth = tokenEndpointAuth
    }
}
