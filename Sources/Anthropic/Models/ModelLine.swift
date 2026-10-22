/// The model line a model belongs to, such as `opus` for both Claude Opus 4.5 and Claude Opus 4.6.
/// Ported from `types/model_line.py`. More lines may be added -- hence `.unknown`.
public enum ModelLine: Sendable, Equatable {
    case haiku
    case sonnet
    case opus
    case fable
    case mythos
    case unknown(String)
}

extension ModelLine: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "haiku": self = .haiku
        case "sonnet": self = .sonnet
        case "opus": self = .opus
        case "fable": self = .fable
        case "mythos": self = .mythos
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .haiku: try container.encode("haiku")
        case .sonnet: try container.encode("sonnet")
        case .opus: try container.encode("opus")
        case .fable: try container.encode("fable")
        case .mythos: try container.encode("mythos")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
