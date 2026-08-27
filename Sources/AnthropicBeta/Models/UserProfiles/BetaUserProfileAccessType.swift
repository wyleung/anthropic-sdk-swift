/// How the platform uses the API on behalf of the entity a user profile represents. `application`:
/// the platform sells a product that uses the API behind the scenes, and the profile represents an
/// individual end-user of that product. `passthrough`: the platform resells raw inference, and the
/// profile identifies the resold-to company. Appears on `BetaUserProfile` (response) and on
/// `BetaUserProfileCreateParams`/`UpdateParams` (request body) -- unlike a query-filter field, a
/// closed-`Literal` body field on both sides of the wire gets a real enum, not a flat `String?`.
/// Superseded by `relationship` under the newer `user-profiles-2026-08-18` header, but still sent
/// by profiles created under the older `user-profiles-2026-03-24` header; both fields can be
/// present simultaneously on a single `BetaUserProfile`. Mirrors
/// `types/beta/beta_user_profile.py`/`user_profile_create_params.py`/`user_profile_update_params.py`.
public enum BetaUserProfileAccessType: Sendable, Equatable {
    case application
    case passthrough
    case unknown(String)
}

extension BetaUserProfileAccessType: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "application": self = .application
        case "passthrough": self = .passthrough
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .application: try container.encode("application")
        case .passthrough: try container.encode("passthrough")
        case .unknown(let value): try container.encode(value)
        }
    }
}
