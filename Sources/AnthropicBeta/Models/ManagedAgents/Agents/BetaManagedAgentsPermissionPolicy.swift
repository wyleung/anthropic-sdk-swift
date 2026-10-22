import Anthropic

/// Ported from the `PermissionPolicy` type alias repeated across every
/// `beta_managed_agents_*_tool_config(_params).py` file (bash/edit/glob/grep/read/write/web_fetch/
/// web_search tool configs, plus the MCP and agent toolset default configs) --
/// `Union[BetaManagedAgentsAlwaysAllowPolicy, BetaManagedAgentsAlwaysAskPolicy, BetaManagedAgentsAutoPolicy]`,
/// discriminated on `type`. Every variant carries no fields beyond the discriminator, and the shape is identical on
/// the params and response side, so a single `Codable` type serves both directions instead of
/// duplicating a params/response pair.
public enum BetaManagedAgentsPermissionPolicy: Sendable, Equatable {
    /// Tool calls are automatically approved without user confirmation.
    case alwaysAllow
    /// Tool calls require user confirmation before execution.
    case alwaysAsk
    /// The server decides each call individually: it judges, from the tool, its input and the session so
    /// far, whether the call is safe (evaluates to allow) or high-risk (deny); a call it cannot judge
    /// evaluates to ask. The per-call verdict arrives on the tool-use event's `evaluation`.
    case auto
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
        case "auto": self = .auto
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
        case .auto: try container.encode("auto", forKey: .type)
        case .unknown: break
        }
    }
}
