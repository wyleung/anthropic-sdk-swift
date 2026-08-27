import Anthropic

/// An input memory store the dream reads from. The dream never mutates this store unless it is
/// also the destination: with `output_behavior {type: "update_existing"}` the job consolidates
/// this store in place. Ported from `beta_dream_memory_store_input.py`.
public struct BetaDreamMemoryStoreInput: Codable, Sendable, Equatable {
    public let memoryStoreId: String
    public let type: String

    public init(memoryStoreId: String, type: String = "memory_store") {
        self.memoryStoreId = memoryStoreId
        self.type = type
    }
}

/// Input session transcripts the dream reads. Ported from `beta_dream_sessions_input.py`.
public struct BetaDreamSessionsInput: Codable, Sendable, Equatable {
    public let sessionIds: [String]
    public let type: String

    public init(sessionIds: [String], type: String = "sessions") {
        self.sessionIds = sessionIds
        self.type = type
    }
}

/// Ported from `beta_dream_input.py` -- `Union[BetaDreamMemoryStoreInput, BetaDreamSessionsInput]`,
/// discriminated on `type`.
public enum BetaDreamInput: Sendable, Equatable {
    case memoryStore(BetaDreamMemoryStoreInput)
    case sessions(BetaDreamSessionsInput)
    case unknown(type: String, raw: JSONValue)
}

extension BetaDreamInput: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "memory_store": self = .memoryStore(try BetaDreamMemoryStoreInput(from: decoder))
        case "sessions": self = .sessions(try BetaDreamSessionsInput(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .memoryStore(let value): try value.encode(to: encoder)
        case .sessions(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Request-side counterpart to `BetaDreamInput`. Ported from `beta_dream_input_param.py`.
public enum BetaDreamInputParam: Sendable, Equatable {
    case memoryStore(memoryStoreId: String)
    case sessions(sessionIds: [String])
}

extension BetaDreamInputParam: Encodable {
    private enum CodingKeys: String, CodingKey {
        case memoryStoreId
        case sessionIds
        case type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .memoryStore(let memoryStoreId):
            try container.encode(memoryStoreId, forKey: .memoryStoreId)
            try container.encode("memory_store", forKey: .type)
        case .sessions(let sessionIds):
            try container.encode(sessionIds, forKey: .sessionIds)
            try container.encode("sessions", forKey: .type)
        }
    }
}
