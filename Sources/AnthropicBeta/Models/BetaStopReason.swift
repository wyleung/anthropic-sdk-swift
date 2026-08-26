/// Ported from `beta_stop_reason.py`. Deliberately not reusing GA's `StopReason` + its generic
/// `.unknown` fallback: `.compaction` is a real documented value, not an edge case, so it gets a
/// first-class case here rather than falling back to raw-string preservation.
public enum BetaStopReason: Sendable, Equatable {
    case endTurn
    case maxTokens
    case stopSequence
    case toolUse
    case pauseTurn
    case refusal
    case modelContextWindowExceeded
    case compaction
    case unknown(String)
}

extension BetaStopReason: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "end_turn": self = .endTurn
        case "max_tokens": self = .maxTokens
        case "stop_sequence": self = .stopSequence
        case "tool_use": self = .toolUse
        case "pause_turn": self = .pauseTurn
        case "refusal": self = .refusal
        case "model_context_window_exceeded": self = .modelContextWindowExceeded
        case "compaction": self = .compaction
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .endTurn: try container.encode("end_turn")
        case .maxTokens: try container.encode("max_tokens")
        case .stopSequence: try container.encode("stop_sequence")
        case .toolUse: try container.encode("tool_use")
        case .pauseTurn: try container.encode("pause_turn")
        case .refusal: try container.encode("refusal")
        case .modelContextWindowExceeded: try container.encode("model_context_window_exceeded")
        case .compaction: try container.encode("compaction")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
