import Anthropic

/// Lifecycle status of a Dream. Ported from `beta_dream_status.py` (`Literal["pending", "running",
/// "completed", "failed", "canceled"]`), with the usual forward-compat `.unknown` fallback.
public enum BetaDreamStatus: Sendable, Equatable {
    case pending
    case running
    case completed
    case failed
    case canceled
    case unknown(String)
}

extension BetaDreamStatus: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "pending": self = .pending
        case "running": self = .running
        case "completed": self = .completed
        case "failed": self = .failed
        case "canceled": self = .canceled
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .pending: try container.encode("pending")
        case .running: try container.encode("running")
        case .completed: try container.encode("completed")
        case .failed: try container.encode("failed")
        case .canceled: try container.encode("canceled")
        case .unknown(let value): try container.encode(value)
        }
    }
}
