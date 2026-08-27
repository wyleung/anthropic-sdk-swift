import Anthropic

/// Resolved `agent` definition for a single `session_thread`. Snapshot of the agent at thread
/// creation time -- the multiagent roster is not repeated here; read it from `Session.agent`.
/// Ported from `beta_managed_agents_session_thread_agent.py`. `skills`/`tools` reuse the existing
/// Slice-2 `BetaManagedAgentsSkill`/`BetaManagedAgentsAgentTool` unions -- their local `Skill`/
/// `Tool` type aliases are byte-identical to `beta_managed_agents_agent.py`'s.
public struct BetaManagedAgentsSessionThreadAgent: Codable, Sendable, Equatable {
    public let id: String
    public let description: String?
    public let mcpServers: [BetaManagedAgentsMCPServerURLDefinition]
    public let model: BetaManagedAgentsModelConfig
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
        self.name = name
        self.skills = skills
        self.system = system
        self.tools = tools
        self.type = type
        self.version = version
    }
}

/// Ported from the `Agent` union local to both `beta_managed_agents_session_multiagent_coordinator.py`
/// (`SessionMultiagentCoordinator.agents`) and `beta_managed_agents_session_thread.py`
/// (`SessionThread.agent`) -- Python re-declares the identical
/// `Union[BetaManagedAgentsSessionThreadAgent, BetaManagedAgentsAdvisor]` in both files under the
/// same local name `Agent`; this port collapses them into one shared discriminated union.
public enum BetaManagedAgentsCoordinatorAgent: Sendable, Equatable {
    case agent(BetaManagedAgentsSessionThreadAgent)
    case advisor(BetaManagedAgentsAdvisor)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsCoordinatorAgent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "agent": self = .agent(try BetaManagedAgentsSessionThreadAgent(from: decoder))
        case "advisor": self = .advisor(try BetaManagedAgentsAdvisor(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agent(let value): try value.encode(to: encoder)
        case .advisor(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Resolved coordinator topology with full agent definitions for each roster member. Ported from
/// `beta_managed_agents_session_multiagent_coordinator.py`. The `type` field is always the literal
/// `"coordinator"`.
public struct BetaManagedAgentsSessionMultiagentCoordinator: Codable, Sendable, Equatable {
    public let agents: [BetaManagedAgentsCoordinatorAgent]
    public let type: String

    public init(agents: [BetaManagedAgentsCoordinatorAgent], type: String = "coordinator") {
        self.agents = agents
        self.type = type
    }
}
