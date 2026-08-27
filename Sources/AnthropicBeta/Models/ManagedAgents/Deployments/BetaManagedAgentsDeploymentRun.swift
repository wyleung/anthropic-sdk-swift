import Anthropic

/// The run was started manually by creating a session directly against the deployment.
public struct BetaManagedAgentsManualTriggerContext: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "manual") {
        self.type = type
    }
}

/// The run was fired by the deployment's cron schedule.
public struct BetaManagedAgentsScheduleTriggerContext: Codable, Sendable, Equatable {
    public let scheduledAt: String
    public let type: String

    public init(scheduledAt: String, type: String = "schedule") {
        self.scheduledAt = scheduledAt
        self.type = type
    }
}

/// Ported from `beta_managed_agents_trigger_context.py` -- `Union[ScheduleTriggerContext,
/// ManualTriggerContext]`, discriminated on `type`.
public enum BetaManagedAgentsTriggerContext: Sendable, Equatable {
    case schedule(BetaManagedAgentsScheduleTriggerContext)
    case manual(BetaManagedAgentsManualTriggerContext)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsTriggerContext: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "schedule": self = .schedule(try BetaManagedAgentsScheduleTriggerContext(from: decoder))
        case "manual": self = .manual(try BetaManagedAgentsManualTriggerContext(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .schedule(let value): try value.encode(to: encoder)
        case .manual(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// A persistent, append-only record of a single deployment execution. Records session creation
/// success or failure -- no session lifecycle tracking. Ported from
/// `beta_managed_agents_deployment_run.py`. Exactly one of `sessionId`/`error` is non-nil.
public struct BetaManagedAgentsDeploymentRun: Codable, Sendable, Equatable {
    public let id: String
    public let agent: BetaManagedAgentsAgentReference
    public let createdAt: String
    public let deploymentId: String
    public let error: BetaManagedAgentsDeploymentRunError?
    public let sessionId: String?
    public let triggerContext: BetaManagedAgentsTriggerContext
    public let type: String

    public init(
        id: String,
        agent: BetaManagedAgentsAgentReference,
        createdAt: String,
        deploymentId: String,
        error: BetaManagedAgentsDeploymentRunError? = nil,
        sessionId: String? = nil,
        triggerContext: BetaManagedAgentsTriggerContext,
        type: String = "deployment_run"
    ) {
        self.id = id
        self.agent = agent
        self.createdAt = createdAt
        self.deploymentId = deploymentId
        self.error = error
        self.sessionId = sessionId
        self.triggerContext = triggerContext
        self.type = type
    }
}
