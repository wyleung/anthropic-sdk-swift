/// Ported from `beta_managed_agents_environment_variable_create_params.py`. `secretName` is
/// immutable after create (absent from the update params); `secretValue` is write-only (never
/// returned by the response type).
public struct BetaManagedAgentsEnvironmentVariableCreateParams: Encodable, Sendable, Equatable {
    public var networking: BetaManagedAgentsCredentialNetworkingParams
    public var secretName: String
    public var secretValue: String
    public var type = "environment_variable"
    public var injectionLocation: BetaManagedAgentsInjectionLocationParams?

    public init(
        networking: BetaManagedAgentsCredentialNetworkingParams,
        secretName: String,
        secretValue: String,
        injectionLocation: BetaManagedAgentsInjectionLocationParams? = nil
    ) {
        self.networking = networking
        self.secretName = secretName
        self.secretValue = secretValue
        self.injectionLocation = injectionLocation
    }
}

/// Ported from `beta_managed_agents_environment_variable_update_params.py`. `secretName` is absent
/// (immutable); `networking`, when provided, is a full replacement rather than a merge.
public struct BetaManagedAgentsEnvironmentVariableUpdateParams: Encodable, Sendable, Equatable {
    public var type = "environment_variable"
    public var injectionLocation: BetaManagedAgentsInjectionLocationUpdateParams?
    public var networking: BetaManagedAgentsCredentialNetworkingParams?
    public var secretValue: String?

    public init(
        injectionLocation: BetaManagedAgentsInjectionLocationUpdateParams? = nil,
        networking: BetaManagedAgentsCredentialNetworkingParams? = nil,
        secretValue: String? = nil
    ) {
        self.injectionLocation = injectionLocation
        self.networking = networking
        self.secretValue = secretValue
    }
}

/// Ported from `beta_managed_agents_environment_variable_auth_response.py`. No `secretValue` --
/// sensitive fields are never returned in responses.
public struct BetaManagedAgentsEnvironmentVariableAuthResponse: Codable, Sendable, Equatable {
    public let injectionLocation: BetaManagedAgentsInjectionLocationResponse
    public let networking: BetaManagedAgentsCredentialNetworkingResponse
    public let secretName: String
    public let type: String

    public init(
        injectionLocation: BetaManagedAgentsInjectionLocationResponse,
        networking: BetaManagedAgentsCredentialNetworkingResponse,
        secretName: String,
        type: String = "environment_variable"
    ) {
        self.injectionLocation = injectionLocation
        self.networking = networking
        self.secretName = secretName
        self.type = type
    }
}
