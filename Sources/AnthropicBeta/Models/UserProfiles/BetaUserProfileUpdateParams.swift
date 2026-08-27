/// Mirrors `types/beta/user_profile_update_params.py`. `accessType`/`externalId`/`name`/
/// `relationship` are all plain 2-state fields (omit to leave unchanged, pass a value to replace)
/// -- none of their docstrings document a distinct null-clears-the-field state, unlike
/// `BetaEnvironmentUpdateParams.description`'s genuine tri-state. `metadata` is the standard
/// per-key patch (outer `nil` omits the field; a present dictionary's `nil` values clear that key,
/// non-nil values upsert it).
public struct BetaUserProfileUpdateParams: Encodable, Sendable, Equatable {
    public var accessType: BetaUserProfileAccessType?
    public var externalId: String?
    public var metadata: [String: String?]?
    public var name: String?
    public var relationship: BetaUserProfileRelationship?

    public init(
        accessType: BetaUserProfileAccessType? = nil,
        externalId: String? = nil,
        metadata: [String: String?]? = nil,
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
