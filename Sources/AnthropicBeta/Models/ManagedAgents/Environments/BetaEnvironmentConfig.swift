import Anthropic

/// Ported from the `Config` type alias in `types/beta/beta_environment.py`
/// (`Union[BetaCloudConfig, BetaSelfHostedConfig]`), discriminated on `type`.
public enum BetaEnvironmentConfig: Sendable, Equatable {
    case cloud(BetaCloudConfig)
    case selfHosted(BetaSelfHostedConfig)
    case unknown(type: String, raw: JSONValue)
}

extension BetaEnvironmentConfig: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "cloud": self = .cloud(try BetaCloudConfig(from: decoder))
        case "self_hosted": self = .selfHosted(try BetaSelfHostedConfig(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .cloud(let value): try value.encode(to: encoder)
        case .selfHosted(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/beta_cloud_config.py`.
public struct BetaCloudConfig: Codable, Sendable, Equatable {
    public let networking: BetaEnvironmentNetworking
    public let packages: BetaPackages
    public let type: String

    public init(networking: BetaEnvironmentNetworking, packages: BetaPackages, type: String = "cloud") {
        self.networking = networking
        self.packages = packages
        self.type = type
    }
}

/// Ported from `types/beta/beta_self_hosted_config.py` -- carries no fields beyond the
/// discriminator; a self-hosted environment's networking/packages are the operator's concern, not
/// something Anthropic's API configures.
public struct BetaSelfHostedConfig: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "self_hosted") {
        self.type = type
    }
}
