import Anthropic

/// An Anthropic-authored skill attached to an agent, as returned in a `BetaManagedAgentsAgent`
/// response. Ported from `beta_managed_agents_anthropic_skill.py`. Unlike the params-side
/// equivalent, `version` is always resolved here -- a create/update request may omit it to mean
/// "latest", but the response always reports the concrete version that was actually pinned.
public struct BetaManagedAgentsAnthropicSkill: Codable, Sendable, Equatable {
    public let skillId: String
    public let type: String
    public let version: String

    public init(skillId: String, type: String = "anthropic", version: String) {
        self.skillId = skillId
        self.type = type
        self.version = version
    }
}

/// A user-authored custom skill attached to an agent. Ported from
/// `beta_managed_agents_custom_skill.py`.
public struct BetaManagedAgentsCustomSkill: Codable, Sendable, Equatable {
    public let skillId: String
    public let type: String
    public let version: String

    public init(skillId: String, type: String = "custom", version: String) {
        self.skillId = skillId
        self.type = type
        self.version = version
    }
}

/// Ported from the `Skill` type alias in `beta_managed_agents_agent.py` --
/// `Union[BetaManagedAgentsAnthropicSkill, BetaManagedAgentsCustomSkill]`, discriminated on `type`.
public enum BetaManagedAgentsSkill: Sendable, Equatable {
    case anthropic(BetaManagedAgentsAnthropicSkill)
    case custom(BetaManagedAgentsCustomSkill)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSkill: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "anthropic": self = .anthropic(try BetaManagedAgentsAnthropicSkill(from: decoder))
        case "custom": self = .custom(try BetaManagedAgentsCustomSkill(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .anthropic(let value): try value.encode(to: encoder)
        case .custom(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `beta_managed_agents_anthropic_skill_params.py`. `version` is optional -- "omit to
/// use the latest version".
public struct BetaManagedAgentsAnthropicSkillParams: Encodable, Sendable, Equatable {
    public let skillId: String
    public let type = "anthropic"
    public let version: String?

    public init(skillId: String, version: String? = nil) {
        self.skillId = skillId
        self.version = version
    }
}

/// Ported from `beta_managed_agents_custom_skill_params.py`.
public struct BetaManagedAgentsCustomSkillParams: Encodable, Sendable, Equatable {
    public let skillId: String
    public let type = "custom"
    public let version: String?

    public init(skillId: String, version: String? = nil) {
        self.skillId = skillId
        self.version = version
    }
}

/// Ported from `beta_managed_agents_skill_params.py`'s `Skill` union --
/// `Union[BetaManagedAgentsAnthropicSkillParams, BetaManagedAgentsCustomSkillParams]`. Request-only
/// (no `.unknown` fallback), plain switch in `encode(to:)` since each leaf already carries its own
/// fixed `type` discriminator.
public enum BetaManagedAgentsSkillParams: Sendable, Equatable {
    case anthropic(BetaManagedAgentsAnthropicSkillParams)
    case custom(BetaManagedAgentsCustomSkillParams)
}

extension BetaManagedAgentsSkillParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .anthropic(let value): try value.encode(to: encoder)
        case .custom(let value): try value.encode(to: encoder)
        }
    }
}
