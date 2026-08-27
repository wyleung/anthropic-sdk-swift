/// One entry in `BetaUserProfile.trustGrants`, keyed by grant name. Mirrors
/// `types/beta/beta_user_profile_trust_grant.py`.
public struct BetaUserProfileTrustGrant: Codable, Sendable, Equatable {
    public let status: BetaUserProfileTrustGrantStatus

    public init(status: BetaUserProfileTrustGrantStatus) {
        self.status = status
    }
}
