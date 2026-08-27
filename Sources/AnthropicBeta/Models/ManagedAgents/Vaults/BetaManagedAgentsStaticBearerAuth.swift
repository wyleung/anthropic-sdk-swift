/// Ported from `beta_managed_agents_static_bearer_create_params.py`. `mcpServerUrl` is immutable
/// after create (absent from the update params); `token` is write-only (never returned by the
/// response type).
public struct BetaManagedAgentsStaticBearerCreateParams: Encodable, Sendable, Equatable {
    public var token: String
    public var mcpServerUrl: String
    public var type = "static_bearer"

    public init(token: String, mcpServerUrl: String) {
        self.token = token
        self.mcpServerUrl = mcpServerUrl
    }
}

/// Ported from `beta_managed_agents_static_bearer_update_params.py`. `mcpServerUrl` is absent
/// (immutable).
public struct BetaManagedAgentsStaticBearerUpdateParams: Encodable, Sendable, Equatable {
    public var type = "static_bearer"
    public var token: String?

    public init(token: String? = nil) {
        self.token = token
    }
}

/// Ported from `beta_managed_agents_static_bearer_auth_response.py`. No `token` -- sensitive fields
/// are never returned in responses.
public struct BetaManagedAgentsStaticBearerAuthResponse: Codable, Sendable, Equatable {
    public let mcpServerUrl: String
    public let type: String

    public init(mcpServerUrl: String, type: String = "static_bearer") {
        self.mcpServerUrl = mcpServerUrl
        self.type = type
    }
}
