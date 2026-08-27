/// Returned by `BetaUserProfiles.createEnrollmentUrl`. Mirrors
/// `types/beta/beta_user_profile_enrollment_url.py`.
public struct BetaUserProfileEnrollmentURL: Codable, Sendable, Equatable {
    public let expiresAt: String
    public let type: String
    public let url: String

    public init(expiresAt: String, type: String = "enrollment_url", url: String) {
        self.expiresAt = expiresAt
        self.type = type
        self.url = url
    }
}
