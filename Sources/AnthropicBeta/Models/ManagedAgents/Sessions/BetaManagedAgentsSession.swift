import Anthropic

/// A Managed Agents `session`, as returned by `client.beta.sessions.{create,retrieve,update}` and
/// as an item in `client.beta.sessions.list`. Ported from `beta_managed_agents_session.py`.
public struct BetaManagedAgentsSession: Codable, Sendable, Equatable {
    public let id: String
    public let agent: BetaManagedAgentsSessionAgent
    public let archivedAt: String?
    public let budget: BetaManagedAgentsBudgetLimit?
    public let createdAt: String
    public let environmentId: String
    public let metadata: [String: String]
    public let outcomeEvaluations: [BetaManagedAgentsOutcomeEvaluationResource]
    public let resources: [BetaManagedAgentsSessionResource]
    public let stats: BetaManagedAgentsSessionStats
    public let status: BetaManagedAgentsSessionStatus
    public let title: String?
    public let type: String
    public let updatedAt: String
    public let usage: BetaManagedAgentsSessionUsage
    public let vaultIds: [String]
    public let deploymentId: String?

    public init(
        id: String,
        agent: BetaManagedAgentsSessionAgent,
        archivedAt: String? = nil,
        budget: BetaManagedAgentsBudgetLimit? = nil,
        createdAt: String,
        environmentId: String,
        metadata: [String: String],
        outcomeEvaluations: [BetaManagedAgentsOutcomeEvaluationResource],
        resources: [BetaManagedAgentsSessionResource],
        stats: BetaManagedAgentsSessionStats,
        status: BetaManagedAgentsSessionStatus,
        title: String? = nil,
        type: String = "session",
        updatedAt: String,
        usage: BetaManagedAgentsSessionUsage,
        vaultIds: [String],
        deploymentId: String? = nil
    ) {
        self.id = id
        self.agent = agent
        self.archivedAt = archivedAt
        self.budget = budget
        self.createdAt = createdAt
        self.environmentId = environmentId
        self.metadata = metadata
        self.outcomeEvaluations = outcomeEvaluations
        self.resources = resources
        self.stats = stats
        self.status = status
        self.title = title
        self.type = type
        self.updatedAt = updatedAt
        self.usage = usage
        self.vaultIds = vaultIds
        self.deploymentId = deploymentId
    }
}
