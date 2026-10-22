import Anthropic

/// `types/beta/beta_skill.py` is now field-identical to GA's `Skill`: upstream's Beta Skills namespace
/// stopped sending the dated `skills-2025-10-02` beta header and returns the GA shapes (with
/// `Beta`-prefixed names). It replaces the earlier `BetaSkillSummary`, whose `displayTitle`,
/// `latestVersion` and bare-string `source` were the legacy shape that header selected.
public typealias BetaSkill = Skill

/// `types/beta/skill_delete_response.py` is field-identical to GA's `DeletedSkill`.
public typealias BetaDeletedSkill = DeletedSkill

/// `types/beta/beta_container.py` is field-identical to GA's `Container` -- both wrap the same
/// `skills: [ContainerSkill]?` shape (`types/beta/beta_container_skill.py` -- renamed from `BetaSkill`, which
/// now names the Skills resource -- matches `ContainerSkill` exactly).
public typealias BetaContainer = Container
