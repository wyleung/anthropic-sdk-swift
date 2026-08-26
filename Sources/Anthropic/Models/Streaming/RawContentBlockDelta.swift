public struct TextDelta: Codable, Sendable, Equatable {
    public let type = "text_delta"
    public let text: String

    private enum CodingKeys: String, CodingKey {
        case type, text
    }
}

public struct InputJSONDelta: Codable, Sendable, Equatable {
    public let type = "input_json_delta"
    public let partialJson: String

    private enum CodingKeys: String, CodingKey {
        case type, partialJson
    }
}

public struct CitationsDelta: Codable, Sendable, Equatable {
    public let type = "citations_delta"
    public let citation: TextCitation

    private enum CodingKeys: String, CodingKey {
        case type, citation
    }
}

public struct ThinkingDelta: Codable, Sendable, Equatable {
    public let type = "thinking_delta"
    public let thinking: String

    private enum CodingKeys: String, CodingKey {
        case type, thinking
    }
}

public struct SignatureDelta: Codable, Sendable, Equatable {
    public let type = "signature_delta"
    public let signature: String

    private enum CodingKeys: String, CodingKey {
        case type, signature
    }
}

/// Ported from `types/raw_content_block_delta.py`'s 5-case discriminated union.
public enum RawContentBlockDelta: Sendable, Equatable {
    case text(TextDelta)
    case inputJSON(InputJSONDelta)
    case citations(CitationsDelta)
    case thinking(ThinkingDelta)
    case signature(SignatureDelta)
    case unknown(type: String, raw: JSONValue)
}

extension RawContentBlockDelta: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "text_delta":
            self = .text(try TextDelta(from: decoder))
        case "input_json_delta":
            self = .inputJSON(try InputJSONDelta(from: decoder))
        case "citations_delta":
            self = .citations(try CitationsDelta(from: decoder))
        case "thinking_delta":
            self = .thinking(try ThinkingDelta(from: decoder))
        case "signature_delta":
            self = .signature(try SignatureDelta(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let delta): try delta.encode(to: encoder)
        case .inputJSON(let delta): try delta.encode(to: encoder)
        case .citations(let delta): try delta.encode(to: encoder)
        case .thinking(let delta): try delta.encode(to: encoder)
        case .signature(let delta): try delta.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
