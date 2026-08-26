public struct ContainerSkill: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case anthropic
        case custom
    }

    public let skillId: String
    public let type: Kind
    public let version: String
}
