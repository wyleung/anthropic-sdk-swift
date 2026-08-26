import Anthropic

/// Ported from `types/beta/beta_thinking_delta.py`. Diverges from GA's `ThinkingDelta` by one
/// field: `estimatedTokens` is a per-frame increment of a coarse, lossy running token estimate,
/// present only when the `thinking-token-count-2026-05-13` beta is set. `usage.outputTokens`
/// remains the authoritative count -- this is a display hint, not billable.
public struct BetaThinkingDelta: Codable, Sendable, Equatable {
    public let type = "thinking_delta"
    public let thinking: String
    public let estimatedTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case type, thinking, estimatedTokens
    }
}

/// Ported from `types/beta/beta_compaction_content_block_delta.py`. No GA equivalent -- each
/// frame fully replaces (not appends to) the target `.compaction` block's `content`/
/// `encryptedContent`, unlike every other delta kind here.
public struct BetaCompactionContentBlockDelta: Codable, Sendable, Equatable {
    public let type = "compaction_delta"
    public let content: String?
    public let encryptedContent: String?

    private enum CodingKeys: String, CodingKey {
        case type, content, encryptedContent
    }
}

/// Ported from `types/beta/beta_raw_content_block_delta.py`'s 6-case discriminated union. Reuses
/// GA's `TextDelta`, `InputJSONDelta`, `CitationsDelta`, and `SignatureDelta` directly (confirmed
/// field-identical to their Beta counterparts); `thinking_delta` gets a dedicated
/// `BetaThinkingDelta` for the extra `estimatedTokens` field, and `compaction_delta` is a new
/// sixth case with no GA equivalent at all.
public enum BetaRawContentBlockDelta: Sendable, Equatable {
    case text(TextDelta)
    case inputJSON(InputJSONDelta)
    case citations(CitationsDelta)
    case thinking(BetaThinkingDelta)
    case signature(SignatureDelta)
    case compaction(BetaCompactionContentBlockDelta)
    case unknown(type: String, raw: JSONValue)
}

extension BetaRawContentBlockDelta: Codable {
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
            self = .thinking(try BetaThinkingDelta(from: decoder))
        case "signature_delta":
            self = .signature(try SignatureDelta(from: decoder))
        case "compaction_delta":
            self = .compaction(try BetaCompactionContentBlockDelta(from: decoder))
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
        case .compaction(let delta): try delta.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
