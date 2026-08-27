/// The kind of mutation a `memory_version` records. Every non-no-op mutation to a memory appends
/// exactly one version row with one of these values. Appears both as a response-payload field
/// (`BetaManagedAgentsMemoryVersion.operation`) and as a `BetaMemoryVersions.list` query filter, so
/// -- unlike the query-only `BetaManagedAgentsMemoryView` -- it gets a dedicated bare-string enum
/// with a forward-compat fallback, mirroring `BetaManagedAgentsModelSpeed`. Mirrors
/// `types/beta/memory_stores/beta_managed_agents_memory_version_operation.py`.
public enum BetaManagedAgentsMemoryVersionOperation: Sendable, Equatable {
    case created
    case modified
    case deleted
    case unknown(String)
}

extension BetaManagedAgentsMemoryVersionOperation: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "created": self = .created
        case "modified": self = .modified
        case "deleted": self = .deleted
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .created: try container.encode("created")
        case .modified: try container.encode("modified")
        case .deleted: try container.encode("deleted")
        case .unknown(let value): try container.encode(value)
        }
    }
}
