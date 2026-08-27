import Anthropic

/// Ported from the local `Tool` union alias in `beta_managed_agents_agent.py` --
/// `Union[BetaManagedAgentsAgentToolset20260401, BetaManagedAgentsMCPToolset, BetaManagedAgentsCustomTool]`,
/// discriminated on `type`. Named `BetaManagedAgentsAgentTool` rather than a bare `Tool`/`BetaTool`
/// to avoid colliding with the existing GA `Tool`/`ToolUnionParam` types in this codebase.
public enum BetaManagedAgentsAgentTool: Sendable, Equatable {
    case agentToolset20260401(BetaManagedAgentsAgentToolset20260401)
    case mcpToolset(BetaManagedAgentsMCPToolset)
    case custom(BetaManagedAgentsCustomTool)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsAgentTool: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "agent_toolset_20260401":
            self = .agentToolset20260401(try BetaManagedAgentsAgentToolset20260401(from: decoder))
        case "mcp_toolset":
            self = .mcpToolset(try BetaManagedAgentsMCPToolset(from: decoder))
        case "custom":
            self = .custom(try BetaManagedAgentsCustomTool(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agentToolset20260401(let value): try value.encode(to: encoder)
        case .mcpToolset(let value): try value.encode(to: encoder)
        case .custom(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `beta_managed_agents_agent_tool_config_params.py`'s top-level `Tool` union -- the
/// params-side counterpart to `BetaManagedAgentsAgentTool`. Request-only (no `.unknown`
/// fallback); each leaf already carries its own fixed `type` discriminator, so `encode(to:)` is a
/// plain switch.
public enum BetaManagedAgentsAgentToolParams: Sendable, Equatable {
    case agentToolset20260401(BetaManagedAgentsAgentToolset20260401Params)
    case mcpToolset(BetaManagedAgentsMCPToolsetParams)
    case custom(BetaManagedAgentsCustomToolParams)
}

extension BetaManagedAgentsAgentToolParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agentToolset20260401(let value): try value.encode(to: encoder)
        case .mcpToolset(let value): try value.encode(to: encoder)
        case .custom(let value): try value.encode(to: encoder)
        }
    }
}
