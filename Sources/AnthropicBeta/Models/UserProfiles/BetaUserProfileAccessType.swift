import Anthropic

/// How the platform uses the API on behalf of the entity a user profile represents: `application` (an
/// individual end-user of the platform's product) or `passthrough` (a company the platform resells Claude
/// access to). Identical to GA's `UserProfileAccessType`. It replaced the old `relationship` field --
/// upstream's Beta types dropped `relationship` "in favor of `access_type`" (Python 1.3.0).
public typealias BetaUserProfileAccessType = UserProfileAccessType
