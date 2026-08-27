/// Ported from the `Networking` type alias in `types/beta/beta_cloud_config_params.py`
/// (`Union[BetaUnrestrictedNetworkParam, BetaLimitedNetworkParams]`). Params-side unions carry no
/// `.unknown` fallback -- these are encode-only, so there's no forward-compat decode need.
public enum BetaNetworkingParams: Encodable, Sendable, Equatable {
    case unrestricted(BetaUnrestrictedNetworkParam)
    case limited(BetaLimitedNetworkParams)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .unrestricted(let value): try value.encode(to: encoder)
        case .limited(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/beta_unrestricted_network_param.py`.
public struct BetaUnrestrictedNetworkParam: Encodable, Sendable, Equatable {
    public var type: String = "unrestricted"

    public init() {}
}

/// Ported from `types/beta/beta_limited_network_params.py`. Every field besides `type` defaults to
/// null server-side, and on update an omitted field preserves the existing value -- since the
/// default (`false` / empty list) is always directly expressible as a value, plain single-optionals
/// are sufficient here (no need for the `??` tri-state used by `BetaEnvironmentUpdateParams.description`).
public struct BetaLimitedNetworkParams: Encodable, Sendable, Equatable {
    public var type: String = "limited"
    public var allowMcpServers: Bool?
    public var allowPackageManagers: Bool?
    public var allowedHosts: [String]?

    public init(
        allowMcpServers: Bool? = nil,
        allowPackageManagers: Bool? = nil,
        allowedHosts: [String]? = nil
    ) {
        self.allowMcpServers = allowMcpServers
        self.allowPackageManagers = allowPackageManagers
        self.allowedHosts = allowedHosts
    }
}
