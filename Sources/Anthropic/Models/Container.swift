public struct Container: Codable, Sendable, Equatable {
    public let id: String
    public let expiresAt: String
    public let skills: [ContainerSkill]?
}
