/// Ported from `types/beta/beta_advisor_tool_result_error.py` and
/// `beta_advisor_tool_result_error_param.py` -- both declare the same closed `error_code` set, one
/// as a response `BaseModel` and one as a request `TypedDict`, so a single `Codable` enum (following
/// `BetaStopReason`'s open-enum-with-`.unknown` convention) serves both directions.
public struct BetaAdvisorToolResultError: Codable, Sendable, Equatable {
    public enum ErrorCode: Sendable, Equatable {
        case maxUsesExceeded
        case promptTooLong
        case tooManyRequests
        case overloaded
        case unavailable
        case executionTimeExceeded
        case modelNotFound
        case unknown(String)
    }

    public let errorCode: ErrorCode
    public let type = "advisor_tool_result_error"

    public init(errorCode: ErrorCode) {
        self.errorCode = errorCode
    }

    private enum CodingKeys: String, CodingKey {
        case errorCode, type
    }
}

extension BetaAdvisorToolResultError.ErrorCode: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "max_uses_exceeded": self = .maxUsesExceeded
        case "prompt_too_long": self = .promptTooLong
        case "too_many_requests": self = .tooManyRequests
        case "overloaded": self = .overloaded
        case "unavailable": self = .unavailable
        case "execution_time_exceeded": self = .executionTimeExceeded
        case "model_not_found": self = .modelNotFound
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .maxUsesExceeded: try container.encode("max_uses_exceeded")
        case .promptTooLong: try container.encode("prompt_too_long")
        case .tooManyRequests: try container.encode("too_many_requests")
        case .overloaded: try container.encode("overloaded")
        case .unavailable: try container.encode("unavailable")
        case .executionTimeExceeded: try container.encode("execution_time_exceeded")
        case .modelNotFound: try container.encode("model_not_found")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
