import Anthropic

/// Ported from `deployment_update_params.py`. Every field is a PATCH-merge: omitting a Swift
/// initializer argument (`nil`) leaves the outer property `nil`, which Swift's synthesized
/// `Encodable` conformance omits from the JSON body entirely (preserves the existing value
/// server-side) -- same convention as `BetaEnvironmentUpdateParams`. `resources`/`vaultIds` are
/// plain `[T]?`: `nil` omits/preserves, and both an explicit empty array and a populated array are
/// sent as-is (either achieves "clear" server-side per the docstring) -- no tri-state wrapper
/// needed. `metadata` uses the standard per-key-sentinel patch (`[String: String?]?`).
public struct BetaDeploymentUpdateParams: Encodable, Sendable, Equatable {
    public var agent: BetaDeploymentAgentParam?
    public var budget: BetaManagedAgentsBudgetLimitParams?
    public var description: String?
    public var environmentId: String?
    public var initialEvents: [BetaManagedAgentsDeploymentInitialEventParam]?
    public var metadata: [String: String?]?
    public var name: String?
    public var resources: [BetaManagedAgentsSessionResourceParam]?
    public var schedule: BetaManagedAgentsScheduleParams?
    public var vaultIds: [String]?

    public init(
        agent: BetaDeploymentAgentParam? = nil,
        budget: BetaManagedAgentsBudgetLimitParams? = nil,
        description: String? = nil,
        environmentId: String? = nil,
        initialEvents: [BetaManagedAgentsDeploymentInitialEventParam]? = nil,
        metadata: [String: String?]? = nil,
        name: String? = nil,
        resources: [BetaManagedAgentsSessionResourceParam]? = nil,
        schedule: BetaManagedAgentsScheduleParams? = nil,
        vaultIds: [String]? = nil
    ) {
        self.agent = agent
        self.budget = budget
        self.description = description
        self.environmentId = environmentId
        self.initialEvents = initialEvents
        self.metadata = metadata
        self.name = name
        self.resources = resources
        self.schedule = schedule
        self.vaultIds = vaultIds
    }
}
