import Anthropic

public struct BetaRawMessageStartEvent: Codable, Sendable, Equatable {
    public let type = "message_start"
    public let message: BetaMessage

    private enum CodingKeys: String, CodingKey {
        case type, message
    }
}

public struct BetaRawMessageDeltaEvent: Codable, Sendable, Equatable {
    public struct Delta: Codable, Sendable, Equatable {
        public let container: BetaContainer?
        public let stopDetails: BetaRefusalStopDetails?
        public let stopReason: BetaStopReason?
        public let stopSequence: String?
    }

    public let type = "message_delta"
    public let contextManagement: JSONValue?
    public let delta: Delta
    public let usage: BetaMessageDeltaUsage

    private enum CodingKeys: String, CodingKey {
        case type, contextManagement, delta, usage
    }
}

public struct BetaRawMessageStopEvent: Codable, Sendable, Equatable {
    public let type = "message_stop"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

public struct BetaRawContentBlockStartEvent: Codable, Sendable, Equatable {
    public let type = "content_block_start"
    public let contentBlock: BetaContentBlock
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case type, contentBlock, index
    }
}

public struct BetaRawContentBlockDeltaEvent: Codable, Sendable, Equatable {
    public let type = "content_block_delta"
    public let delta: BetaRawContentBlockDelta
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case type, delta, index
    }
}

public struct BetaRawContentBlockStopEvent: Codable, Sendable, Equatable {
    public let type = "content_block_stop"
    public let index: Int

    private enum CodingKeys: String, CodingKey {
        case type, index
    }
}

/// Ported from `types/beta/beta_raw_message_stream_event.py`'s 6-case discriminated union -- the
/// Beta analogue of GA's `RawMessageStreamEvent`. `content_block_start`'s payload is
/// `BetaContentBlock` and `content_block_delta`'s is `BetaRawContentBlockDelta`; `message_delta`
/// additionally carries a top-level `contextManagement` field GA's event doesn't have.
public enum BetaRawMessageStreamEvent: Sendable, Equatable {
    case messageStart(BetaRawMessageStartEvent)
    case messageDelta(BetaRawMessageDeltaEvent)
    case messageStop(BetaRawMessageStopEvent)
    case contentBlockStart(BetaRawContentBlockStartEvent)
    case contentBlockDelta(BetaRawContentBlockDeltaEvent)
    case contentBlockStop(BetaRawContentBlockStopEvent)
    case unknown(type: String, raw: JSONValue)
}

extension BetaRawMessageStreamEvent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "message_start":
            self = .messageStart(try BetaRawMessageStartEvent(from: decoder))
        case "message_delta":
            self = .messageDelta(try BetaRawMessageDeltaEvent(from: decoder))
        case "message_stop":
            self = .messageStop(try BetaRawMessageStopEvent(from: decoder))
        case "content_block_start":
            self = .contentBlockStart(try BetaRawContentBlockStartEvent(from: decoder))
        case "content_block_delta":
            self = .contentBlockDelta(try BetaRawContentBlockDeltaEvent(from: decoder))
        case "content_block_stop":
            self = .contentBlockStop(try BetaRawContentBlockStopEvent(from: decoder))
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
