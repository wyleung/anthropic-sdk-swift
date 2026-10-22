import Anthropic

/// Identical to GA's `UserProfileExternalUserDetails`. Beta's response carries it only when the request sends
/// no legacy `user-profiles-*` beta header; this namespace sends `user-profiles-2026-08-18` by default, so for
/// profiles with external user details prefer `client.userProfiles`.
public typealias BetaUserProfileExternalUserDetails = UserProfileExternalUserDetails

/// Identical to GA's `UserProfileExternalUserDetailsParams`. Not accepted under the legacy
/// `user-profiles-2026-03-24` and `user-profiles-2026-08-18` beta headers -- which this namespace sends by
/// default; use `client.userProfiles`, or override `anthropic-beta`, to send it.
public typealias BetaUserProfileExternalUserDetailsParams = UserProfileExternalUserDetailsParams

/// `types/beta/beta_deleted_user_profile.py` is field-identical to GA's `DeletedUserProfile`.
public typealias BetaDeletedUserProfile = DeletedUserProfile

/// `types/beta/user_profiles/beta_user_profile_action_url.py` is field-identical to GA's `UserProfileActionURL`.
public typealias BetaUserProfileActionURL = UserProfileActionURL

/// `types/beta/user_profiles/beta_user_profile_enroll_end_user_action_param.py` is field-identical to GA's.
public typealias BetaUserProfileEnrollEndUserActionParam = UserProfileEnrollEndUserActionParam
