import Anthropic

/// `types/beta/skills/beta_skill_version.py` is now field-identical to GA's `SkillVersion` (the legacy
/// `directory` and `version` fields went with the dated beta header). Version ids are now `skver_...`;
/// `versions.retrieve` also accepts the literal `"latest"` (`delete` takes a real id only).
public typealias BetaSkillVersion = SkillVersion

public typealias BetaDeletedSkillVersion = DeletedSkillVersion
