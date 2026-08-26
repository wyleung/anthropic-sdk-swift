public struct SkillParams: Encodable, Sendable, Equatable {
    public enum Kind: String, Encodable, Sendable, Equatable {
        case anthropic
        case custom
    }

    public let skillId: String
    public let type: Kind
    public let version: String?

    public init(skillId: String, type: Kind, version: String? = nil) {
        self.skillId = skillId
        self.type = type
        self.version = version
    }
}

public struct ContainerParams: Encodable, Sendable, Equatable {
    public let id: String?
    public let skills: [SkillParams]?

    public init(id: String? = nil, skills: [SkillParams]? = nil) {
        self.id = id
        self.skills = skills
    }
}

public enum MessageCreateParamsContainerParam: Sendable, Equatable {
    case container(ContainerParams)
    case id(String)
}

extension MessageCreateParamsContainerParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .container(let value): try container.encode(value)
        case .id(let value): try container.encode(value)
        }
    }
}

extension MessageCreateParamsContainerParam: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .id(value)
    }
}
