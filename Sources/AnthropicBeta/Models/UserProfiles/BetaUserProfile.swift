/// A `user_profile` object, representing the entity (end-user, resold-to company, or the platform's own
/// usage) an API key's traffic is attributed to. Mirrors `types/beta/beta_user_profile.py`.
///
/// This is the *legacy-header* shape (the namespace sends `user-profiles-2026-08-18`): it carries
/// `trustGrants` and the top-level `externalId`/`externalUserOnboardedAt`. The richer current model --
/// enforcement status and actions, programs -- is `UserProfile`, served by `client.userProfiles`.
public struct BetaUserProfile: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let metadata: [String: String]
    public let trustGrants: [String: BetaUserProfileTrustGrant]
    public let type: String
    public let updatedAt: String
    public let accessType: BetaUserProfileAccessType?
    public let externalId: String?
    /// Present only when the request sends no legacy `user-profiles-*` beta header.
    public let externalUserDetails: BetaUserProfileExternalUserDetails?
    /// When the entity opened its account with the platform (RFC 3339); a legacy-header field.
    public let externalUserOnboardedAt: String?
    public let name: String?

    public init(
        id: String,
        createdAt: String,
        metadata: [String: String],
        trustGrants: [String: BetaUserProfileTrustGrant],
        type: String = "user_profile",
        updatedAt: String,
        accessType: BetaUserProfileAccessType? = nil,
        externalId: String? = nil,
        externalUserDetails: BetaUserProfileExternalUserDetails? = nil,
        externalUserOnboardedAt: String? = nil,
        name: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.metadata = metadata
        self.trustGrants = trustGrants
        self.type = type
        self.updatedAt = updatedAt
        self.accessType = accessType
        self.externalId = externalId
        self.externalUserDetails = externalUserDetails
        self.externalUserOnboardedAt = externalUserOnboardedAt
        self.name = name
    }
}
