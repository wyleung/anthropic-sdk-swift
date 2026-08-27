/// Mirrors `types/beta/user_profile_create_params.py`. Every field is optional -- there is no
/// required body field at all.
public struct BetaUserProfileCreateParams: Encodable, Sendable, Equatable {
    public var accessType: BetaUserProfileAccessType?
    public var externalId: String?
    public var metadata: [String: String]?
    public var name: String?
    public var relationship: BetaUserProfileRelationship?

    public init(
        accessType: BetaUserProfileAccessType? = nil,
        externalId: String? = nil,
        metadata: [String: String]? = nil,
        name: String? = nil,
        relationship: BetaUserProfileRelationship? = nil
    ) {
        self.accessType = accessType
        self.externalId = externalId
        self.metadata = metadata
        self.name = name
        self.relationship = relationship
    }
}
