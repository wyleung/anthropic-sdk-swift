/// The text delta for one `text` content block plus the entire accumulated text so far.
public struct TextEvent: Sendable, Equatable {
    public let text: String
    public let snapshot: String
}

/// A newly-received citation plus every citation accumulated for its content block so far.
public struct CitationEvent: Sendable, Equatable {
    public let citation: TextCitation
    public let snapshot: [TextCitation]
}

/// The thinking-text delta for one `thinking` content block plus the accumulated text so far.
public struct ThinkingEvent: Sendable, Equatable {
    public let thinking: String
    public let snapshot: String
}

/// The signature of a completed `thinking` content block.
public struct SignatureEvent: Sendable, Equatable {
    public let signature: String
}

/// A raw partial-JSON delta for a tool call's `input`, plus the best-effort parse of everything
/// accumulated so far (via `PartialJSON`).
public struct InputJSONEvent: Sendable, Equatable {
    public let partialJSON: String
    public let snapshot: JSONValue
}

/// `message_stop` enriched with the final accumulated `Message` snapshot.
public struct MessageStopEvent: Sendable, Equatable {
    public let message: Message
}

/// `content_block_stop` enriched with the finalized content block at that index.
public struct ContentBlockStopEvent: Sendable, Equatable {
    public let index: Int
    public let contentBlock: ContentBlock
}

/// The higher-level stream event union `MessageStream` publishes: the 6 raw per-chunk events
/// (`message_start`/`message_delta`/`content_block_start`/`content_block_delta` passed through
/// as-is, `message_stop`/`content_block_stop` enriched with the accumulated snapshot) plus 5
/// derived convenience events synthesized from `content_block_delta` by delta type. Ported from
/// `lib/streaming/_types.py`'s `MessageStreamEvent` union.
///
/// Unlike the wire-level `RawMessageStreamEvent`, this type is never decoded from JSON -- it's
/// built locally by `buildMessageStreamEvents` from an already-decoded raw event plus the current
/// snapshot -- so it deliberately skips `Codable`, unlike this codebase's usual response-model
/// convention, which exists to mirror the API's wire shape.
public enum MessageStreamEvent: Sendable, Equatable {
    case messageStart(RawMessageStartEvent)
    case messageDelta(RawMessageDeltaEvent)
    case messageStop(MessageStopEvent)
    case contentBlockStart(RawContentBlockStartEvent)
    case contentBlockDelta(RawContentBlockDeltaEvent)
    case contentBlockStop(ContentBlockStopEvent)
    case text(TextEvent)
    case citation(CitationEvent)
    case thinking(ThinkingEvent)
    case signature(SignatureEvent)
    case inputJSON(InputJSONEvent)
}
