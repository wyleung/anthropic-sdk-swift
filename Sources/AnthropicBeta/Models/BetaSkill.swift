import Anthropic

/// Ported from `types/beta/skill_create_response.py`, `skill_retrieve_response.py`, and
/// `skill_list_response.py` -- all three are field-identical, so this collapses them into one
/// type rather than three parallel ones. Distinct from GA's `Skill`: no `latestVersionId` field,
/// and `source`/`displayTitle` differ in name and optionality (`source` is a bare `String` here,
/// not the `{type: ...}` wrapper `SkillSource` GA uses).
public struct BetaSkillSummary: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let displayTitle: String?
    public let latestVersion: String?
    public let source: String
    public let type: String
    public let updatedAt: String
}

/// `types/beta/skill_delete_response.py` is field-identical to GA's `DeletedSkill`.
public typealias BetaDeletedSkill = DeletedSkill

/// `types/beta/beta_container.py` is field-identical to GA's `Container` -- both wrap the same
/// `skills: [ContainerSkill]?` shape (`types/beta/beta_skill.py` matches `ContainerSkill` exactly).
public typealias BetaContainer = Container
