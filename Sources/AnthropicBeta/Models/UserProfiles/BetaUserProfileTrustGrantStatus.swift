/// Ported from `beta_user_profile_trust_grant.py`'s bare `Literal["active", "pending", "rejected"]`.
public enum BetaUserProfileTrustGrantStatus: Sendable, Equatable {
    case active
    case pending
    case rejected
    case unknown(String)
}

extension BetaUserProfileTrustGrantStatus: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "active": self = .active
        case "pending": self = .pending
        case "rejected": self = .rejected
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active: try container.encode("active")
        case .pending: try container.encode("pending")
        case .rejected: try container.encode("rejected")
        case .unknown(let value): try container.encode(value)
        }
    }
}
