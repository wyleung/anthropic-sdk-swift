import Anthropic

/// Ported from `types/beta/skills/version_create_response.py` (identical to
/// `version_retrieve_response.py`/`version_list_response.py`). Adds `directory` and `version`
/// beyond GA's `SkillVersion`, so this duplicates the type rather than reusing it.
public struct BetaSkillVersion: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let description: String
    public let directory: String
    public let name: String
    public let skillId: String
    public let type: String
    public let version: String
}

/// `types/beta/skills/version_delete_response.py` is field-identical to GA's `DeletedSkillVersion`.
public typealias BetaDeletedSkillVersion = DeletedSkillVersion
