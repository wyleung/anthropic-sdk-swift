/// Mirrors `types/beta/user_profile_update_params.py`. `accessType`, `externalId`, `externalUserDetails`,
/// `externalUserOnboardedAt` and `name` are plain 2-state fields (omit to leave unchanged, pass a value to
/// replace) -- none of their docstrings document a distinct null-clears state, unlike
/// `BetaEnvironmentUpdateParams.description`'s genuine tri-state. `metadata` is the standard per-key patch
/// (outer `nil` omits the field; a present dictionary's `nil` values clear that key, non-nil values upsert it).
/// `relationship` is gone: upstream replaced it with `accessType`.
public struct BetaUserProfileUpdateParams: Encodable, Sendable, Equatable {
    public var accessType: BetaUserProfileAccessType?
    public var externalId: String?
    /// Not accepted under the legacy beta headers this namespace sends by default.
    public var externalUserDetails: BetaUserProfileExternalUserDetailsParams?
    public var externalUserOnboardedAt: String?
    public var metadata: [String: String?]?
    public var name: String?

    public init(
        accessType: BetaUserProfileAccessType? = nil,
        externalId: String? = nil,
        externalUserDetails: BetaUserProfileExternalUserDetailsParams? = nil,
        externalUserOnboardedAt: String? = nil,
        metadata: [String: String?]? = nil,
        name: String? = nil
    ) {
        self.accessType = accessType
        self.externalId = externalId
        self.externalUserDetails = externalUserDetails
        self.externalUserOnboardedAt = externalUserOnboardedAt
        self.metadata = metadata
        self.name = name
    }
}
