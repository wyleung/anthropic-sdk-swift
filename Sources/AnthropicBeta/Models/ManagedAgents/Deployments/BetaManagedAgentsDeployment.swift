import Anthropic

/// A deployment is a configured instance of an agent -- it binds the agent to everything needed
/// to run it autonomously: an environment, credentials, initial events, and an optional schedule.
/// Ported from `beta_managed_agents_deployment.py`. The `type` field is always the literal
/// `"deployment"`.
public struct BetaManagedAgentsDeployment: Codable, Sendable, Equatable {
    public let id: String
    public let agent: BetaManagedAgentsAgentReference
    public let archivedAt: String?
    public let createdAt: String
    public let description: String?
    public let environmentId: String
    public let initialEvents: [BetaManagedAgentsDeploymentInitialEvent]
    public let metadata: [String: String]
    public let name: String
    public let pausedReason: BetaManagedAgentsDeploymentPausedReason?
    public let resources: [BetaManagedAgentsSessionResourceConfig]
    public let schedule: BetaManagedAgentsSchedule?
    public let status: BetaManagedAgentsDeploymentStatus
    public let type: String
    public let updatedAt: String
    public let vaultIds: [String]
    public let budget: BetaManagedAgentsBudgetLimit?

    public init(
        id: String,
        agent: BetaManagedAgentsAgentReference,
        archivedAt: String? = nil,
        createdAt: String,
        description: String? = nil,
        environmentId: String,
        initialEvents: [BetaManagedAgentsDeploymentInitialEvent],
        metadata: [String: String],
        name: String,
        pausedReason: BetaManagedAgentsDeploymentPausedReason? = nil,
        resources: [BetaManagedAgentsSessionResourceConfig],
        schedule: BetaManagedAgentsSchedule? = nil,
        status: BetaManagedAgentsDeploymentStatus,
        type: String = "deployment",
        updatedAt: String,
        vaultIds: [String],
        budget: BetaManagedAgentsBudgetLimit? = nil
    ) {
        self.id = id
        self.agent = agent
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.description = description
        self.environmentId = environmentId
        self.initialEvents = initialEvents
        self.metadata = metadata
        self.name = name
        self.pausedReason = pausedReason
        self.resources = resources
        self.schedule = schedule
        self.status = status
        self.type = type
        self.updatedAt = updatedAt
        self.vaultIds = vaultIds
        self.budget = budget
    }
}
