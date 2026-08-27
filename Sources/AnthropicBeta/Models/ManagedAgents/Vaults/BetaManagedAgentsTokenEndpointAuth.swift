import Anthropic

// MARK: - none

/// Ported from `beta_managed_agents_token_endpoint_auth_none_param.py`.
public struct BetaManagedAgentsTokenEndpointAuthNoneParam: Encodable, Sendable, Equatable {
    public var type = "none"

    public init() {}
}

/// Ported from `beta_managed_agents_token_endpoint_auth_none_response.py`.
public struct BetaManagedAgentsTokenEndpointAuthNoneResponse: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "none") {
        self.type = type
    }
}

// MARK: - client_secret_basic

/// Ported from `beta_managed_agents_token_endpoint_auth_basic_param.py`.
public struct BetaManagedAgentsTokenEndpointAuthBasicParam: Encodable, Sendable, Equatable {
    public var clientSecret: String
    public var type = "client_secret_basic"

    public init(clientSecret: String) {
        self.clientSecret = clientSecret
    }
}

/// Ported from `beta_managed_agents_token_endpoint_auth_basic_response.py`. `clientSecret` is
/// write-only and never returned.
public struct BetaManagedAgentsTokenEndpointAuthBasicResponse: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "client_secret_basic") {
        self.type = type
    }
}

/// Ported from `beta_managed_agents_token_endpoint_auth_basic_update_param.py`.
public struct BetaManagedAgentsTokenEndpointAuthBasicUpdateParam: Encodable, Sendable, Equatable {
    public var type = "client_secret_basic"
    public var clientSecret: String?

    public init(clientSecret: String? = nil) {
        self.clientSecret = clientSecret
    }
}

// MARK: - client_secret_post

/// Ported from `beta_managed_agents_token_endpoint_auth_post_param.py`.
public struct BetaManagedAgentsTokenEndpointAuthPostParam: Encodable, Sendable, Equatable {
    public var clientSecret: String
    public var type = "client_secret_post"

    public init(clientSecret: String) {
        self.clientSecret = clientSecret
    }
}

/// Ported from `beta_managed_agents_token_endpoint_auth_post_response.py`. `clientSecret` is
/// write-only and never returned.
public struct BetaManagedAgentsTokenEndpointAuthPostResponse: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "client_secret_post") {
        self.type = type
    }
}

/// Ported from `beta_managed_agents_token_endpoint_auth_post_update_param.py`.
public struct BetaManagedAgentsTokenEndpointAuthPostUpdateParam: Encodable, Sendable, Equatable {
    public var type = "client_secret_post"
    public var clientSecret: String?

    public init(clientSecret: String? = nil) {
        self.clientSecret = clientSecret
    }
}

// MARK: - Unions

/// Ported from the `TokenEndpointAuth` union local to `beta_managed_agents_mcp_oauth_refresh_params.py`
/// (create-side, 3 variants). Request-only (no `.unknown`); each leaf carries its own fixed `type`
/// literal, so `encode(to:)` is a plain switch.
public enum BetaManagedAgentsTokenEndpointAuthParam: Sendable, Equatable {
    case none(BetaManagedAgentsTokenEndpointAuthNoneParam)
    case clientSecretBasic(BetaManagedAgentsTokenEndpointAuthBasicParam)
    case clientSecretPost(BetaManagedAgentsTokenEndpointAuthPostParam)
}

extension BetaManagedAgentsTokenEndpointAuthParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .none(let value): try value.encode(to: encoder)
        case .clientSecretBasic(let value): try value.encode(to: encoder)
        case .clientSecretPost(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from the `TokenEndpointAuth` union local to `beta_managed_agents_mcp_oauth_refresh_update_params.py`.
/// Only 2 variants -- no `beta_managed_agents_token_endpoint_auth_none_update_param.py` file exists
/// in the Python SDK, so once a refresh's auth method is `none` it cannot be changed via update.
/// Request-only (no `.unknown`).
public enum BetaManagedAgentsTokenEndpointAuthUpdateParam: Sendable, Equatable {
    case clientSecretBasic(BetaManagedAgentsTokenEndpointAuthBasicUpdateParam)
    case clientSecretPost(BetaManagedAgentsTokenEndpointAuthPostUpdateParam)
}

extension BetaManagedAgentsTokenEndpointAuthUpdateParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .clientSecretBasic(let value): try value.encode(to: encoder)
        case .clientSecretPost(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from the `TokenEndpointAuth` union local to `beta_managed_agents_mcp_oauth_refresh_response.py`
/// (response-side, 3 variants). `.unknown` handles any future variant.
public enum BetaManagedAgentsTokenEndpointAuthResponse: Sendable, Equatable {
    case none(BetaManagedAgentsTokenEndpointAuthNoneResponse)
    case clientSecretBasic(BetaManagedAgentsTokenEndpointAuthBasicResponse)
    case clientSecretPost(BetaManagedAgentsTokenEndpointAuthPostResponse)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsTokenEndpointAuthResponse: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "none":
            self = .none(try BetaManagedAgentsTokenEndpointAuthNoneResponse(from: decoder))
        case "client_secret_basic":
            self = .clientSecretBasic(try BetaManagedAgentsTokenEndpointAuthBasicResponse(from: decoder))
        case "client_secret_post":
            self = .clientSecretPost(try BetaManagedAgentsTokenEndpointAuthPostResponse(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .none(let value): try value.encode(to: encoder)
        case .clientSecretBasic(let value): try value.encode(to: encoder)
        case .clientSecretPost(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
