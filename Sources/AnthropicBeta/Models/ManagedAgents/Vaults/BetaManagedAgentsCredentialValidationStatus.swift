/// Ported from `beta_managed_agents_credential_validation_status.py`'s bare
/// `Literal["valid", "invalid", "unknown"]`. Note `"unknown"` is itself a legitimate status value
/// here (validation was inconclusive), so it is modeled as `.inconclusive` rather than reusing this
/// codebase's usual `.unknown(String)` fallback name -- `.unrecognized(String)` is the fallback for
/// any value the server adds later that isn't one of these three.
public enum BetaManagedAgentsCredentialValidationStatus: Sendable, Equatable {
    case valid
    case invalid
    case inconclusive
    case unrecognized(String)
}

extension BetaManagedAgentsCredentialValidationStatus: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "valid": self = .valid
        case "invalid": self = .invalid
        case "unknown": self = .inconclusive
        default: self = .unrecognized(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .valid: try container.encode("valid")
        case .invalid: try container.encode("invalid")
        case .inconclusive: try container.encode("unknown")
        case .unrecognized(let value): try container.encode(value)
        }
    }
}
