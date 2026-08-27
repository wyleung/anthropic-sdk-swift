import Anthropic

/// Ported from `deployment_create_params.py`'s local `Agent` alias (`Union[str, BetaManagedAgentsAgentParams]`)
/// -- the agent ID string (pins the latest version) or an explicit `{id, version}` object. Mirrors
/// `BetaAgentModelParam`'s bare-value-or-object pattern.
public enum BetaDeploymentAgentParam: Sendable, Equatable {
    case id(String)
    case agent(BetaManagedAgentsAgentParams)
}

extension BetaDeploymentAgentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .agent(let value): try value.encode(to: encoder)
        }
    }
}

extension BetaDeploymentAgentParam: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .id(value)
    }
}

/// Ported from `deployment_create_params.py`. `agent`/`environmentId`/`initialEvents`/`name` are
/// required; the rest are optional creation-time settings. `resources` reuses the existing
/// `BetaManagedAgentsSessionResourceParam` union from `BetaManagedAgentsSessionResourceParams.swift`.
public struct BetaDeploymentCreateParams: Encodable, Sendable, Equatable {
    public var agent: BetaDeploymentAgentParam
    public var environmentId: String
    public var initialEvents: [BetaManagedAgentsDeploymentInitialEventParam]
    public var name: String
    public var budget: BetaManagedAgentsBudgetLimitParams?
    public var description: String?
    public var metadata: [String: String]?
    public var resources: [BetaManagedAgentsSessionResourceParam]?
    public var schedule: BetaManagedAgentsScheduleParams?
    public var vaultIds: [String]?

    public init(
        agent: BetaDeploymentAgentParam,
        environmentId: String,
        initialEvents: [BetaManagedAgentsDeploymentInitialEventParam],
        name: String,
        budget: BetaManagedAgentsBudgetLimitParams? = nil,
        description: String? = nil,
        metadata: [String: String]? = nil,
        resources: [BetaManagedAgentsSessionResourceParam]? = nil,
        schedule: BetaManagedAgentsScheduleParams? = nil,
        vaultIds: [String]? = nil
    ) {
        self.agent = agent
        self.environmentId = environmentId
        self.initialEvents = initialEvents
        self.name = name
        self.budget = budget
        self.description = description
        self.metadata = metadata
        self.resources = resources
        self.schedule = schedule
        self.vaultIds = vaultIds
    }
}
