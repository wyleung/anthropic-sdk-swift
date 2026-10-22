/// The inference speed mode (`"fast"` enables high output-tokens-per-second inference). Ported
/// from the `speed` literal on `types/usage.py` and `types/message_create_params.py`.
///
/// Open, with an `.unknown` fallback like `StopReason`, because it decodes from `Usage.speed`: a
/// speed newer than this port must not fail the whole `Message`. Some models require the
/// `fast-mode-2026-02-01` beta header for any `speed` value -- pass it in `RequestOptions.headers`.
public enum Speed: Sendable, Equatable {
    case standard
    case fast
    case unknown(String)
}

extension Speed: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "standard": self = .standard
        case "fast": self = .fast
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .standard: try container.encode("standard")
        case .fast: try container.encode("fast")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
