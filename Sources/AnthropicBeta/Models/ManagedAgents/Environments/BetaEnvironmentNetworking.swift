import Anthropic

/// Ported from the `Networking` type alias in `types/beta/beta_cloud_config.py`
/// (`Union[BetaUnrestrictedNetwork, BetaLimitedNetwork]`), discriminated on `type`. Only meaningful
/// inside `BetaCloudConfig` -- self-hosted environments have no networking policy of their own.
public enum BetaEnvironmentNetworking: Sendable, Equatable {
    case unrestricted(BetaUnrestrictedNetwork)
    case limited(BetaLimitedNetwork)
    case unknown(type: String, raw: JSONValue)
}

extension BetaEnvironmentNetworking: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "unrestricted": self = .unrestricted(try BetaUnrestrictedNetwork(from: decoder))
        case "limited": self = .limited(try BetaLimitedNetwork(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .unrestricted(let value): try value.encode(to: encoder)
        case .limited(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/beta_unrestricted_network.py`.
public struct BetaUnrestrictedNetwork: Codable, Sendable, Equatable {
    public let type: String
}

/// Ported from `types/beta/beta_limited_network.py`. Unlike its params-side twin
/// (`BetaLimitedNetworkParams`), every field here is non-optional -- the response always reports
/// the effective policy, never a "preserve existing" gap.
public struct BetaLimitedNetwork: Codable, Sendable, Equatable {
    public let allowMcpServers: Bool
    public let allowPackageManagers: Bool
    public let allowedHosts: [String]
    public let type: String
}
