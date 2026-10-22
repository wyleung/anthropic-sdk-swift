import Anthropic

/// A managed agent, as returned by `client.beta.agents.{create,retrieve,update}` and as an item in
/// `client.beta.agents.list`/`client.beta.agents.versions.list`. Ported from
/// `beta_managed_agents_agent.py`.
public struct BetaManagedAgentsAgent: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let createdAt: String
    public let description: String?
    /// The principal runs carry; `{"type": "service_account"}` when none is named. Optional only because it
    /// postdates this port, so a response without it must still decode.
    public let executionIdentity: BetaManagedAgentsExecutionIdentity?
    public let mcpServers: [BetaManagedAgentsMCPServerURLDefinition]
    public let metadata: [String: String]
    public let model: BetaManagedAgentsModelConfig
    public let multiagent: BetaManagedAgentsMultiagent?
    public let name: String
    public let skills: [BetaManagedAgentsSkill]
    public let system: String?
    public let tools: [BetaManagedAgentsAgentTool]
    public let type: String
    public let updatedAt: String
    public let version: Int

    public init(
        id: String,
        archivedAt: String? = nil,
        createdAt: String,
        description: String? = nil,
        executionIdentity: BetaManagedAgentsExecutionIdentity? = nil,
        mcpServers: [BetaManagedAgentsMCPServerURLDefinition],
        metadata: [String: String],
        model: BetaManagedAgentsModelConfig,
        multiagent: BetaManagedAgentsMultiagent? = nil,
        name: String,
        skills: [BetaManagedAgentsSkill],
        system: String? = nil,
        tools: [BetaManagedAgentsAgentTool],
        type: String = "agent",
        updatedAt: String,
        version: Int
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.description = description
        self.executionIdentity = executionIdentity
        self.mcpServers = mcpServers
        self.metadata = metadata
        self.model = model
        self.multiagent = multiagent
        self.name = name
        self.skills = skills
        self.system = system
        self.tools = tools
        self.type = type
        self.updatedAt = updatedAt
        self.version = version
    }
}
