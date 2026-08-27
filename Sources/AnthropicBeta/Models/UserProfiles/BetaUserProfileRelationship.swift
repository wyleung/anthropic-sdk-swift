/// How the entity behind a user profile relates to the platform that owns the API key. `external`:
/// an individual end-user of the platform. `resold`: a company the platform resells Claude access
/// to. `internal`: the platform's own usage. This is the newer (`user-profiles-2026-08-18`)
/// replacement for `accessType`/`BetaUserProfileAccessType` -- see that type's doc comment for how
/// the two coexist on a single profile. Mirrors
/// `types/beta/beta_user_profile.py`/`user_profile_create_params.py`/`user_profile_update_params.py`.
public enum BetaUserProfileRelationship: Sendable, Equatable {
    case external
    case resold
    case `internal`
    case unknown(String)
}

extension BetaUserProfileRelationship: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "external": self = .external
        case "resold": self = .resold
        case "internal": self = .`internal`
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .external: try container.encode("external")
        case .resold: try container.encode("resold")
        case .`internal`: try container.encode("internal")
        case .unknown(let value): try container.encode(value)
        }
    }
}
