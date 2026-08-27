import Anthropic

/// Ported from `beta_managed_agents_unrestricted_credential_networking_params.py`: the
/// `environment_variable` credential's proxy is allowed to reach any host.
public struct BetaManagedAgentsUnrestrictedCredentialNetworkingParams: Encodable, Sendable, Equatable {
    public var type = "unrestricted"

    public init() {}
}

/// Ported from `beta_managed_agents_limited_credential_networking_params.py`. `allowedHosts` is
/// capped at 16 entries by the server; each entry is a bare hostname, IPv4 address, or `*.`-prefixed
/// wildcard -- no URLs, ports, paths, or IPv6.
public struct BetaManagedAgentsLimitedCredentialNetworkingParams: Encodable, Sendable, Equatable {
    public var allowedHosts: [String]
    public var type = "limited"

    public init(allowedHosts: [String]) {
        self.allowedHosts = allowedHosts
    }
}

/// Ported from `beta_managed_agents_credential_networking_params.py`'s `CredentialNetworkingParams`
/// `TypeAlias`. Request-only (no `.unknown`); each leaf carries its own fixed `type` literal, so
/// `encode(to:)` is a plain switch.
public enum BetaManagedAgentsCredentialNetworkingParams: Sendable, Equatable {
    case unrestricted(BetaManagedAgentsUnrestrictedCredentialNetworkingParams)
    case limited(BetaManagedAgentsLimitedCredentialNetworkingParams)
}

extension BetaManagedAgentsCredentialNetworkingParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .unrestricted(let value): try value.encode(to: encoder)
        case .limited(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from `beta_managed_agents_unrestricted_credential_networking_response.py`.
public struct BetaManagedAgentsUnrestrictedCredentialNetworkingResponse: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "unrestricted") {
        self.type = type
    }
}

/// Ported from `beta_managed_agents_limited_credential_networking_response.py`.
public struct BetaManagedAgentsLimitedCredentialNetworkingResponse: Codable, Sendable, Equatable {
    public let allowedHosts: [String]
    public let type: String

    public init(allowedHosts: [String], type: String = "limited") {
        self.allowedHosts = allowedHosts
        self.type = type
    }
}

/// Ported from the `Networking` union local to `beta_managed_agents_environment_variable_auth_response.py`.
/// `.unknown` handles any future variant.
public enum BetaManagedAgentsCredentialNetworkingResponse: Sendable, Equatable {
    case unrestricted(BetaManagedAgentsUnrestrictedCredentialNetworkingResponse)
    case limited(BetaManagedAgentsLimitedCredentialNetworkingResponse)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsCredentialNetworkingResponse: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "unrestricted":
            self = .unrestricted(try BetaManagedAgentsUnrestrictedCredentialNetworkingResponse(from: decoder))
        case "limited":
            self = .limited(try BetaManagedAgentsLimitedCredentialNetworkingResponse(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
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
