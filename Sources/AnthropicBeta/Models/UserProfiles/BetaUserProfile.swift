/// A `user_profile` object, representing the entity (end-user, resold-to company, or the
/// platform's own usage) an API key's traffic is attributed to. Mirrors
/// `types/beta/beta_user_profile.py`.
///
/// `accessType` and `relationship` describe overlapping concepts under two different beta headers
/// -- `accessType` under the older `user-profiles-2026-03-24`, `relationship` under the newer
/// `user-profiles-2026-08-18` (see `BetaUserProfileAccessType`'s doc comment) -- and can both be
/// present on the same profile; this port doesn't build separate code paths for the two headers,
/// just exposes both optional fields as-is.
public struct BetaUserProfile: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let metadata: [String: String]
    public let trustGrants: [String: BetaUserProfileTrustGrant]
    public let type: String
    public let updatedAt: String
    public let accessType: BetaUserProfileAccessType?
    public let externalId: String?
    public let name: String?
    public let relationship: BetaUserProfileRelationship?

    public init(
        id: String,
        createdAt: String,
        metadata: [String: String],
        trustGrants: [String: BetaUserProfileTrustGrant],
        type: String = "user_profile",
        updatedAt: String,
        accessType: BetaUserProfileAccessType? = nil,
        externalId: String? = nil,
        name: String? = nil,
        relationship: BetaUserProfileRelationship? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.metadata = metadata
        self.trustGrants = trustGrants
        self.type = type
        self.updatedAt = updatedAt
        self.accessType = accessType
        self.externalId = externalId
        self.name = name
        self.relationship = relationship
    }
}
