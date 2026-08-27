import Anthropic

/// Shared status enum for both a `session` and an individual `session_thread`. Python declares
/// these as two textually-separate type aliases with the same four members but different declared
/// order -- `beta_managed_agents_session.py`'s inline `status` literal is
/// `["rescheduling", "running", "idle", "terminated"]`, while
/// `beta_managed_agents_session_thread_status.py`'s `BetaManagedAgentsSessionThreadStatus` is
/// `["running", "idle", "rescheduling", "terminated"]`. Declaration order carries no semantic
/// weight for a `Codable` enum, so this port collapses both into one shared type rather than two
/// structurally-identical duplicates.
public enum BetaManagedAgentsSessionStatus: Sendable, Equatable {
    case rescheduling
    case running
    case idle
    case terminated
    case unknown(String)
}

extension BetaManagedAgentsSessionStatus: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "rescheduling": self = .rescheduling
        case "running": self = .running
        case "idle": self = .idle
        case "terminated": self = .terminated
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .rescheduling: try container.encode("rescheduling")
        case .running: try container.encode("running")
        case .idle: try container.encode("idle")
        case .terminated: try container.encode("terminated")
        case .unknown(let value): try container.encode(value)
        }
    }
}
