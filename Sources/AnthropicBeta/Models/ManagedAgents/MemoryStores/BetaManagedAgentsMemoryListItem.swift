import Anthropic

/// A rolled-up directory marker returned by `BetaMemories.list` when `depth` is set. Indicates that
/// one or more memories exist deeper than the requested depth under this prefix. This is a
/// list-time rollup, not a stored resource; it has no id and no lifecycle. Each prefix counts
/// toward the page `limit` and interleaves with `memory` items in path order. Mirrors
/// `types/beta/memory_stores/beta_managed_agents_memory_prefix.py`.
public struct BetaManagedAgentsMemoryPrefix: Codable, Sendable, Equatable {
    public let path: String
    public let type: String

    public init(path: String, type: String = "memory_prefix") {
        self.path = path
        self.type = type
    }
}

/// Ported from `beta_managed_agents_memory_list_item.py` --
/// `Union[BetaManagedAgentsMemory, BetaManagedAgentsMemoryPrefix]`, discriminated on `type`.
public enum BetaManagedAgentsMemoryListItem: Sendable, Equatable {
    case memory(BetaManagedAgentsMemory)
    case memoryPrefix(BetaManagedAgentsMemoryPrefix)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMemoryListItem: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "memory": self = .memory(try BetaManagedAgentsMemory(from: decoder))
        case "memory_prefix": self = .memoryPrefix(try BetaManagedAgentsMemoryPrefix(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .memory(let value): try value.encode(to: encoder)
        case .memoryPrefix(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
