/// Mirrors `types/beta/user_profile_create_params.py`. Every field is optional -- there is no required body
/// field at all. `relationship` is gone: upstream replaced it with `accessType`.
public struct BetaUserProfileCreateParams: Encodable, Sendable, Equatable {
    public var accessType: BetaUserProfileAccessType?
    /// The platform's own identifier for this user; not enforced unique, maximum 255 characters. A legacy field,
    /// accepted only under the `user-profiles-2026-03-24` and `-08-18` beta headers; without one, send
    /// `externalUserDetails.referenceId`.
    public var externalId: String?
    /// Not accepted under the legacy beta headers this namespace sends by default; see
    /// `BetaUserProfileExternalUserDetailsParams`.
    public var externalUserDetails: BetaUserProfileExternalUserDetailsParams?
    /// When the entity opened its account (RFC 3339). Accepted only under `user-profiles-2026-08-18`; without
    /// a legacy header, send `externalUserDetails.onboardedAt`.
    public var externalUserOnboardedAt: String?
    public var metadata: [String: String]?
    public var name: String?

    public init(
        accessType: BetaUserProfileAccessType? = nil,
        externalId: String? = nil,
        externalUserDetails: BetaUserProfileExternalUserDetailsParams? = nil,
        externalUserOnboardedAt: String? = nil,
        metadata: [String: String]? = nil,
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
