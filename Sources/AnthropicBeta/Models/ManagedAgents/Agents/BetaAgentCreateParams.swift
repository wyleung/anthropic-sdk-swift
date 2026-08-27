import Anthropic

/// Ported from `agent_create_params.py`. All fields besides `model`/`name` are optional and
/// simply omitted from the request body when `nil` -- there's no PATCH-style clear semantics on
/// create (see `BetaAgentUpdateParams` for that).
public struct BetaAgentCreateParams: Encodable, Sendable, Equatable {
    public let model: BetaAgentModelParam
    public let name: String
    public let description: String?
    public let mcpServers: [BetaManagedAgentsURLMCPServerParams]?
    public let metadata: [String: String]?
    public let multiagent: BetaManagedAgentsMultiagentParams?
    public let skills: [BetaManagedAgentsSkillParams]?
    public let system: String?
    public let tools: [BetaManagedAgentsAgentToolParams]?

    public init(
        model: BetaAgentModelParam,
        name: String,
        description: String? = nil,
        mcpServers: [BetaManagedAgentsURLMCPServerParams]? = nil,
        metadata: [String: String]? = nil,
        multiagent: BetaManagedAgentsMultiagentParams? = nil,
        skills: [BetaManagedAgentsSkillParams]? = nil,
        system: String? = nil,
        tools: [BetaManagedAgentsAgentToolParams]? = nil
    ) {
        self.model = model
        self.name = name
        self.description = description
        self.mcpServers = mcpServers
        self.metadata = metadata
        self.multiagent = multiagent
        self.skills = skills
        self.system = system
        self.tools = tools
    }
}
