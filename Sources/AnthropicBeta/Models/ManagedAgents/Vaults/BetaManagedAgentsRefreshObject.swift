/// Outcome of the refresh-token exchange attempted while validating an `mcp_oauth` credential.
/// Ported from `beta_managed_agents_refresh_object.py`'s bare
/// `Literal["succeeded", "failed", "connect_error", "no_refresh_token"]` -- same
/// one-`Codable`-enum-serves-both-directions shape as `BetaManagedAgentsDeploymentStatus`.
public enum BetaManagedAgentsRefreshStatus: Sendable, Equatable {
    case succeeded
    case failed
    case connectError
    case noRefreshToken
    case unknown(String)
}

extension BetaManagedAgentsRefreshStatus: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "succeeded": self = .succeeded
        case "failed": self = .failed
        case "connect_error": self = .connectError
        case "no_refresh_token": self = .noRefreshToken
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .succeeded: try container.encode("succeeded")
        case .failed: try container.encode("failed")
        case .connectError: try container.encode("connect_error")
        case .noRefreshToken: try container.encode("no_refresh_token")
        case .unknown(let value): try container.encode(value)
        }
    }
}

/// Ported from `beta_managed_agents_refresh_object.py`.
public struct BetaManagedAgentsRefreshObject: Codable, Sendable, Equatable {
    public let httpResponse: BetaManagedAgentsRefreshHTTPResponse?
    public let status: BetaManagedAgentsRefreshStatus

    public init(httpResponse: BetaManagedAgentsRefreshHTTPResponse? = nil, status: BetaManagedAgentsRefreshStatus) {
        self.httpResponse = httpResponse
        self.status = status
    }
}
