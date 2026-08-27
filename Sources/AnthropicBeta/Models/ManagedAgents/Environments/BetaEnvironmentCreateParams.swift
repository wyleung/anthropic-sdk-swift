/// Ported from `types/beta/environment_create_params.py`.
public struct BetaEnvironmentCreateParams: Encodable, Sendable, Equatable {
    public var name: String
    public var config: BetaEnvironmentConfigParams?
    public var description: String?
    public var metadata: [String: String]?
    public var scope: BetaEnvironmentScope?

    public init(
        name: String,
        config: BetaEnvironmentConfigParams? = nil,
        description: String? = nil,
        metadata: [String: String]? = nil,
        scope: BetaEnvironmentScope? = nil
    ) {
        self.name = name
        self.config = config
        self.description = description
        self.metadata = metadata
        self.scope = scope
    }
}
