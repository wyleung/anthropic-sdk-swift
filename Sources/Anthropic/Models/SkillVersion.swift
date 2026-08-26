/// Ported from `types/skills/skill_version.py`. Date fields stay `String`, matching
/// `Container.expiresAt`.
public struct SkillVersion: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let description: String
    public let name: String
    public let skillId: String
    public let type: String
}

/// Ported from `types/skills/deleted_skill_version.py`.
public struct DeletedSkillVersion: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
}
