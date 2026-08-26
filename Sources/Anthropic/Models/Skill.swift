/// Ported from `types/skill_source.py`. Modeled as a wrapper struct around a `type` discriminator
/// rather than a bare string enum -- confirmed against both reference SDKs, which type `Skill.source`
/// as an object (`{"type": "custom"}`), not a raw string.
public struct SkillSource: Codable, Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case custom
        case anthropic
        case anthropicExample
        case plugin
        case unknown(String)
    }

    public let type: Kind

    public init(type: Kind) {
        self.type = type
    }
}

extension SkillSource.Kind: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "custom": self = .custom
        case "anthropic": self = .anthropic
        case "anthropic_example": self = .anthropicExample
        case "plugin": self = .plugin
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .custom: try container.encode("custom")
        case .anthropic: try container.encode("anthropic")
        case .anthropicExample: try container.encode("anthropic_example")
        case .plugin: try container.encode("plugin")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// Ported from `types/skill.py`. Date fields stay `String`, matching `Container.expiresAt`.
public struct Skill: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let displayName: String
    public let latestVersionId: String
    public let source: SkillSource
    public let type: String
    public let updatedAt: String
}

/// Ported from `types/deleted_skill.py`.
public struct DeletedSkill: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
}
