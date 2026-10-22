/// A model's lifecycle stage. Ported from the `lifecycle` literal on `types/model_info.py` and
/// `types/model_list_params.py`.
///
/// - `active`: available, open to new adopters, and not scheduled for retirement.
/// - `deprecated`: still callable for organizations with existing access, but closed to new
///   adopters and headed for retirement.
/// - `retired`: no longer available -- inference requests naming it fail. Kept in the catalogue as
///   the historical record.
public enum ModelLifecycle: Sendable, Equatable {
    case active
    case deprecated
    case retired
    case unknown(String)
}

extension ModelLifecycle: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "active": self = .active
        case "deprecated": self = .deprecated
        case "retired": self = .retired
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active: try container.encode("active")
        case .deprecated: try container.encode("deprecated")
        case .retired: try container.encode("retired")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
