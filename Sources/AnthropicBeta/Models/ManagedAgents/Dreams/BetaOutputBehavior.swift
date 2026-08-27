import Anthropic

/// The default destination: the job creates a new output memory store as a clone of the
/// `memory_store` input and writes the consolidated memories into it. The input store is never
/// mutated. Ported from `beta_output_behavior_create_new.py`.
public struct BetaOutputBehaviorCreateNew: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "create_new") { self.type = type }
}

/// The job writes the consolidated memories into this existing memory store instead of creating
/// one. In EAP the store must be the job's own `memory_store` input, so the job consolidates the
/// store in place. Ported from `beta_output_behavior_update_existing.py`.
public struct BetaOutputBehaviorUpdateExisting: Codable, Sendable, Equatable {
    public let memoryStoreId: String
    public let type: String

    public init(memoryStoreId: String, type: String = "update_existing") {
        self.memoryStoreId = memoryStoreId
        self.type = type
    }
}

/// Ported from `beta_output_behavior.py` -- `Union[BetaOutputBehaviorCreateNew,
/// BetaOutputBehaviorUpdateExisting]`, discriminated on `type`. Despite its top-level (not
/// `beta_dream_*`-prefixed) Python file name, this type is currently referenced only by
/// `BetaDream`/`DreamCreateParams` -- confirmed by grepping every other Python resource file.
public enum BetaOutputBehavior: Sendable, Equatable {
    case createNew(BetaOutputBehaviorCreateNew)
    case updateExisting(BetaOutputBehaviorUpdateExisting)
    case unknown(type: String, raw: JSONValue)
}

extension BetaOutputBehavior: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "create_new": self = .createNew(try BetaOutputBehaviorCreateNew(from: decoder))
        case "update_existing": self = .updateExisting(try BetaOutputBehaviorUpdateExisting(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .createNew(let value): try value.encode(to: encoder)
        case .updateExisting(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Request-side counterpart to `BetaOutputBehavior`. Ported from `beta_output_behavior_param.py`.
public enum BetaOutputBehaviorParam: Sendable, Equatable {
    case createNew
    case updateExisting(memoryStoreId: String)
}

extension BetaOutputBehaviorParam: Encodable {
    private enum CodingKeys: String, CodingKey {
        case memoryStoreId
        case type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .createNew:
            try container.encode("create_new", forKey: .type)
        case .updateExisting(let memoryStoreId):
            try container.encode(memoryStoreId, forKey: .memoryStoreId)
            try container.encode("update_existing", forKey: .type)
        }
    }
}
