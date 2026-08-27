import Anthropic

/// Ported from the `PermissionPolicy` type alias repeated across every
/// `beta_managed_agents_*_tool_config(_params).py` file (bash/edit/glob/grep/read/write/web_fetch/
/// web_search tool configs, plus the MCP and agent toolset default configs) --
/// `Union[BetaManagedAgentsAlwaysAllowPolicy, BetaManagedAgentsAlwaysAskPolicy]`, discriminated on
/// `type`. Both variants carry no fields beyond the discriminator, and the shape is identical on
/// the params and response side, so a single `Codable` type serves both directions instead of
/// duplicating a params/response pair.
public enum BetaManagedAgentsPermissionPolicy: Sendable, Equatable {
    /// Tool calls are automatically approved without user confirmation.
    case alwaysAllow
    /// Tool calls require user confirmation before execution.
    case alwaysAsk
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsPermissionPolicy: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "always_allow": self = .alwaysAllow
        case "always_ask": self = .alwaysAsk
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(_, let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var container = encoder.container(keyedBy: DiscriminatorKeys.self)
        switch self {
        case .alwaysAllow: try container.encode("always_allow", forKey: .type)
        case .alwaysAsk: try container.encode("always_ask", forKey: .type)
        case .unknown: break
        }
    }
}
