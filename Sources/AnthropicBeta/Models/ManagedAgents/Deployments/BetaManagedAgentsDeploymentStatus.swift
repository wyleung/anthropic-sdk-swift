import Anthropic

/// Lifecycle status of a deployment. Ported from `beta_managed_agents_deployment_status.py`'s bare
/// `Literal["active", "paused"]` -- same one-`Codable`-enum-serves-both-directions shape as
/// `BetaManagedAgentsMemoryStoreAccess`.
public enum BetaManagedAgentsDeploymentStatus: Sendable, Equatable {
    case active
    case paused
    case unknown(String)
}

extension BetaManagedAgentsDeploymentStatus: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "active": self = .active
        case "paused": self = .paused
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active: try container.encode("active")
        case .paused: try container.encode("paused")
        case .unknown(let value): try container.encode(value)
        }
    }
}
