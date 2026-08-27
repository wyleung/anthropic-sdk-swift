/// Ported from the `Config` type alias shared verbatim between `environment_create_params.py` and
/// `environment_update_params.py` (`Union[BetaCloudConfigParams, BetaSelfHostedConfigParams]") --
/// one Swift type serves both `BetaEnvironmentCreateParams.config` and
/// `BetaEnvironmentUpdateParams.config`. No `.unknown` fallback: params are encode-only.
public enum BetaEnvironmentConfigParams: Encodable, Sendable, Equatable {
    case cloud(BetaCloudConfigParams)
    case selfHosted(BetaSelfHostedConfigParams)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .cloud(let value): try value.encode(to: encoder)
        case .selfHosted(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/beta_cloud_config_params.py`. Fields default to null; on update, an
/// omitted field preserves the existing value -- since "preserve" is already expressible as `nil`
/// and the default networking/packages state is directly expressible as a value, plain
/// single-optionals are sufficient (no `??` tri-state needed here).
public struct BetaCloudConfigParams: Encodable, Sendable, Equatable {
    public var type: String = "cloud"
    public var networking: BetaNetworkingParams?
    public var packages: BetaPackagesParams?

    public init(
        networking: BetaNetworkingParams? = nil,
        packages: BetaPackagesParams? = nil
    ) {
        self.networking = networking
        self.packages = packages
    }
}

/// Ported from `types/beta/beta_self_hosted_config_params.py` -- carries no fields beyond the
/// discriminator.
public struct BetaSelfHostedConfigParams: Encodable, Sendable, Equatable {
    public var type: String = "self_hosted"

    public init() {}
}
