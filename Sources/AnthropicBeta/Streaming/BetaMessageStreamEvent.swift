import Anthropic

/// The text delta for one `text` content block plus the entire accumulated text so far.
public struct BetaTextEvent: Sendable, Equatable {
    public let text: String
    public let snapshot: String
}

/// A newly-received citation plus every citation accumulated for its content block so far.
public struct BetaCitationEvent: Sendable, Equatable {
    public let citation: TextCitation
    public let snapshot: [TextCitation]
}

/// The thinking-text delta for one `thinking` content block plus the accumulated text so far.
public struct BetaThinkingEvent: Sendable, Equatable {
    public let thinking: String
    public let snapshot: String
}

/// The signature of a completed `thinking` content block.
public struct BetaSignatureEvent: Sendable, Equatable {
    public let signature: String
}

/// A raw partial-JSON delta for a tool call's `input`, plus the best-effort parse of everything
/// accumulated so far (via `PartialJSON`).
public struct BetaInputJSONEvent: Sendable, Equatable {
    public let partialJSON: String
    public let snapshot: JSONValue
}

/// `message_stop` enriched with the final accumulated `BetaMessage` snapshot.
public struct BetaMessageStopEvent: Sendable, Equatable {
    public let message: BetaMessage
}

/// `content_block_stop` enriched with the finalized content block at that index.
public struct BetaContentBlockStopEvent: Sendable, Equatable {
    public let index: Int
    public let contentBlock: BetaContentBlock
}

/// A `compaction_delta` against a `.compaction` block, carrying that block's current
/// `content`/`encryptedContent` after the delta's full-replace is applied. Unlike
/// `BetaTextEvent`/`BetaThinkingEvent`, there's no separate delta-chunk field to report --
/// `compaction_delta` frames replace rather than append -- so this only carries the current
/// value. Ported from `lib/streaming/_beta_types.py`'s `BetaCompactionEvent`. No GA equivalent.
public struct BetaCompactionEvent: Sendable, Equatable {
    public let content: String?
    public let encryptedContent: String?
}

/// The higher-level stream event union `BetaMessageStream` publishes: the Beta analogue of GA's
/// `MessageStreamEvent`. Same 6 raw per-chunk events and same 5 GA-shared derived events, plus a
/// sixth derived event -- `compaction` -- synthesized from `compaction_delta` frames, which have
/// no GA counterpart. Ported from `lib/streaming/_beta_types.py`'s `ParsedBetaMessageStreamEvent`
/// union.
///
/// Like GA's `MessageStreamEvent`, this is never decoded from JSON -- it's built locally by
/// `buildBetaMessageStreamEvents` -- so it deliberately skips `Codable`.
public enum BetaMessageStreamEvent: Sendable, Equatable {
    case messageStart(BetaRawMessageStartEvent)
    case messageDelta(BetaRawMessageDeltaEvent)
    case messageStop(BetaMessageStopEvent)
    case contentBlockStart(BetaRawContentBlockStartEvent)
    case contentBlockDelta(BetaRawContentBlockDeltaEvent)
    case contentBlockStop(BetaContentBlockStopEvent)
    case text(BetaTextEvent)
    case citation(BetaCitationEvent)
    case thinking(BetaThinkingEvent)
    case signature(BetaSignatureEvent)
    case inputJSON(BetaInputJSONEvent)
    case compaction(BetaCompactionEvent)
}
