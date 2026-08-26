public struct RawMessageStartEvent: Codable, Sendable, Equatable {
    public let type = "message_start"
    public let message: Message

    private enum CodingKeys: String, CodingKey {
        case type, message
    }
}

public struct RawMessageDeltaEvent: Codable, Sendable, Equatable {
    public struct Delta: Codable, Sendable, Equatable {
        public let container: Container?
        public let stopDetails: RefusalStopDetails?
        public let stopReason: StopReason?
        public let stopSequence: String?
    }

    public let type = "message_delta"
    public let delta: Delta
    public let usage: MessageDeltaUsage

    private enum CodingKeys: String, CodingKey {
        case type, delta, usage
    }
}

public struct RawMessageStopEvent: Codable, Sendable, Equatable {
    public let type = "message_stop"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

public struct RawContentBlockStartEvent: Codable, Sendable, Equatable {
    public let type = "content_block_start"
    public let contentBlock: ContentBlock
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case type, contentBlock, index
    }
}

public struct RawContentBlockDeltaEvent: Codable, Sendable, Equatable {
    public let type = "content_block_delta"
    public let delta: RawContentBlockDelta
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case type, delta, index
    }
}

public struct RawContentBlockStopEvent: Codable, Sendable, Equatable {
    public let type = "content_block_stop"
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case type, index
    }
}

/// Ported from `types/raw_message_stream_event.py`'s 6-case discriminated union — the
/// low-level, per-chunk event shape emitted by the SSE decoder, prior to accumulation
/// into a growing `Message` snapshot.
public enum RawMessageStreamEvent: Sendable, Equatable {
    case messageStart(RawMessageStartEvent)
    case messageDelta(RawMessageDeltaEvent)
    case messageStop(RawMessageStopEvent)
    case contentBlockStart(RawContentBlockStartEvent)
    case contentBlockDelta(RawContentBlockDeltaEvent)
    case contentBlockStop(RawContentBlockStopEvent)
    case unknown(type: String, raw: JSONValue)
}

extension RawMessageStreamEvent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "message_start":
            self = .messageStart(try RawMessageStartEvent(from: decoder))
        case "message_delta":
            self = .messageDelta(try RawMessageDeltaEvent(from: decoder))
        case "message_stop":
            self = .messageStop(try RawMessageStopEvent(from: decoder))
        case "content_block_start":
            self = .contentBlockStart(try RawContentBlockStartEvent(from: decoder))
        case "content_block_delta":
            self = .contentBlockDelta(try RawContentBlockDeltaEvent(from: decoder))
        case "content_block_stop":
            self = .contentBlockStop(try RawContentBlockStopEvent(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .messageStart(let event): try event.encode(to: encoder)
        case .messageDelta(let event): try event.encode(to: encoder)
        case .messageStop(let event): try event.encode(to: encoder)
        case .contentBlockStart(let event): try event.encode(to: encoder)
        case .contentBlockDelta(let event): try event.encode(to: encoder)
        case .contentBlockStop(let event): try event.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
