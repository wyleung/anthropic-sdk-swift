import Anthropic

/// Resolved `agent` definition for a `session`: a snapshot of the agent at session creation time.
/// Ported from `beta_managed_agents_session_agent.py`. `skills`/`tools` reuse the existing Slice-2
/// `BetaManagedAgentsSkill`/`BetaManagedAgentsAgentTool` unions -- their local `Skill`/`Tool` type
/// aliases are byte-identical to `beta_managed_agents_agent.py`'s.
public struct BetaManagedAgentsSessionAgent: Codable, Sendable, Equatable {
    public let id: String
    public let description: String?
    public let mcpServers: [BetaManagedAgentsMCPServerURLDefinition]
    public let model: BetaManagedAgentsModelConfig
    public let multiagent: BetaManagedAgentsSessionMultiagentCoordinator?
    public let name: String
    public let skills: [BetaManagedAgentsSkill]
    public let system: String?
    public let tools: [BetaManagedAgentsAgentTool]
    public let type: String
    public let version: Int

    public init(
        id: String,
        description: String? = nil,
        mcpServers: [BetaManagedAgentsMCPServerURLDefinition],
        model: BetaManagedAgentsModelConfig,
        multiagent: BetaManagedAgentsSessionMultiagentCoordinator? = nil,
        name: String,
        skills: [BetaManagedAgentsSkill],
        system: String? = nil,
        tools: [BetaManagedAgentsAgentTool],
        type: String = "agent",
        version: Int
    ) {
        self.id = id
        self.description = description
        self.mcpServers = mcpServers
        self.model = model
        self.multiagent = multiagent
        self.name = name
        self.skills = skills
        self.system = system
        self.tools = tools
        self.type = type
        self.version = version
    }
}
