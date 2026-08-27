import Anthropic

/// Ported from the `Auth` union local to `credential_create_params.py` --
/// `Union[MCPOAuthCreateParams, StaticBearerCreateParams, EnvironmentVariableCreateParams]`.
/// Request-only (no `.unknown`); each leaf carries its own fixed `type` literal, so `encode(to:)` is
/// a plain switch.
public enum BetaCredentialAuthCreateParams: Sendable, Equatable {
    case mcpOAuth(BetaManagedAgentsMCPOAuthCreateParams)
    case staticBearer(BetaManagedAgentsStaticBearerCreateParams)
    case environmentVariable(BetaManagedAgentsEnvironmentVariableCreateParams)
}

extension BetaCredentialAuthCreateParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .mcpOAuth(let value): try value.encode(to: encoder)
        case .staticBearer(let value): try value.encode(to: encoder)
        case .environmentVariable(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from the `Auth` union local to `credential_update_params.py`. Request-only (no
/// `.unknown`).
public enum BetaCredentialAuthUpdateParams: Sendable, Equatable {
    case mcpOAuth(BetaManagedAgentsMCPOAuthUpdateParams)
    case staticBearer(BetaManagedAgentsStaticBearerUpdateParams)
    case environmentVariable(BetaManagedAgentsEnvironmentVariableUpdateParams)
}

extension BetaCredentialAuthUpdateParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .mcpOAuth(let value): try value.encode(to: encoder)
        case .staticBearer(let value): try value.encode(to: encoder)
        case .environmentVariable(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from the `Auth` union local to `beta_managed_agents_credential.py`. `.unknown` handles any
/// future variant.
public enum BetaManagedAgentsCredentialAuth: Sendable, Equatable {
    case mcpOAuth(BetaManagedAgentsMCPOAuthAuthResponse)
    case staticBearer(BetaManagedAgentsStaticBearerAuthResponse)
    case environmentVariable(BetaManagedAgentsEnvironmentVariableAuthResponse)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsCredentialAuth: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "mcp_oauth":
            self = .mcpOAuth(try BetaManagedAgentsMCPOAuthAuthResponse(from: decoder))
        case "static_bearer":
            self = .staticBearer(try BetaManagedAgentsStaticBearerAuthResponse(from: decoder))
        case "environment_variable":
            self = .environmentVariable(try BetaManagedAgentsEnvironmentVariableAuthResponse(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .mcpOAuth(let value): try value.encode(to: encoder)
        case .staticBearer(let value): try value.encode(to: encoder)
        case .environmentVariable(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
