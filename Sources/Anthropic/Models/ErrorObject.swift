/// Ported from `types/shared/invalid_request_error.py`.
public struct InvalidRequestError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/authentication_error.py`.
public struct AuthenticationErrorObject: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/billing_error.py`.
public struct BillingError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/permission_error.py`.
public struct PermissionError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/not_found_error.py`.
public struct NotFoundError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/rate_limit_error.py`.
public struct RateLimitError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/gateway_timeout_error.py`. Note the discriminator value is
/// `"timeout_error"`, not `"gateway_timeout_error"` -- that's how the Python/TS source model it too.
public struct GatewayTimeoutError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/api_error_object.py`.
public struct APIErrorObject: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/overloaded_error.py`.
public struct OverloadedErrorObject: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Ported from `types/shared/error_object.py`'s 9-way discriminated union, keyed on `type`.
/// `AuthenticationErrorObject`/`OverloadedErrorObject` are named to avoid colliding with
/// `AnthropicError`'s own `.authentication`/`.overloaded` cases and Swift's own error protocols.
public enum ErrorObject: Sendable, Equatable {
    case invalidRequest(InvalidRequestError)
    case authentication(AuthenticationErrorObject)
    case billing(BillingError)
    case permission(PermissionError)
    case notFound(NotFoundError)
    case rateLimit(RateLimitError)
    case gatewayTimeout(GatewayTimeoutError)
    case api(APIErrorObject)
    case overloaded(OverloadedErrorObject)
    case unknown(type: String, raw: JSONValue)
}

extension ErrorObject: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "invalid_request_error":
            self = .invalidRequest(try InvalidRequestError(from: decoder))
        case "authentication_error":
            self = .authentication(try AuthenticationErrorObject(from: decoder))
        case "billing_error":
            self = .billing(try BillingError(from: decoder))
        case "permission_error":
            self = .permission(try PermissionError(from: decoder))
        case "not_found_error":
            self = .notFound(try NotFoundError(from: decoder))
        case "rate_limit_error":
            self = .rateLimit(try RateLimitError(from: decoder))
        case "timeout_error":
            self = .gatewayTimeout(try GatewayTimeoutError(from: decoder))
        case "api_error":
            self = .api(try APIErrorObject(from: decoder))
        case "overloaded_error":
            self = .overloaded(try OverloadedErrorObject(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .invalidRequest(let error): try error.encode(to: encoder)
        case .authentication(let error): try error.encode(to: encoder)
        case .billing(let error): try error.encode(to: encoder)
        case .permission(let error): try error.encode(to: encoder)
        case .notFound(let error): try error.encode(to: encoder)
        case .rateLimit(let error): try error.encode(to: encoder)
        case .gatewayTimeout(let error): try error.encode(to: encoder)
        case .api(let error): try error.encode(to: encoder)
        case .overloaded(let error): try error.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `types/shared/error_response.py`.
public struct ErrorResponse: Codable, Sendable, Equatable {
    public let error: ErrorObject
    public let requestId: String?
    public let type: String
}
