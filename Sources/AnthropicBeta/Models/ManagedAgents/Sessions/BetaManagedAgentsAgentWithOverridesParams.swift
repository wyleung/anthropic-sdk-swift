import Anthropic

/// Reference to an `agent` plus optional configuration overrides -- each provided field replaces
/// the agent's value for the caller's use only; the agent resource itself is unchanged. Ported from
/// `beta_managed_agents_agent_with_overrides_params.py`. `model` reuses the existing
/// `BetaAgentModelParam` union (its local `Model` alias is byte-identical to
/// `agent_create_params.py`'s), and `tools` reuses `BetaManagedAgentsAgentToolParams` (its local
/// `Tool` alias is the same 3-variant union used elsewhere).
///
/// Field-by-field docstring semantics: `mcpServers`/`skills`/`tools` are full-replacement arrays --
/// omit to preserve the agent's value, empty array clears. `model`/`version`: omit to use the
/// agent's value; no clear form exists. `system` is the one tri-state field here -- its docstring
/// explicitly says "Set to null to clear the agent's system prompt; omit to preserve it", so it's
/// modeled as a double-optional (`String??`), matching `BetaEnvironmentUpdateParams.description`.
public struct BetaManagedAgentsAgentWithOverridesParams: Encodable, Sendable, Equatable {
    public var id: String
    public var type = "agent_with_overrides"
    public var mcpServers: [BetaManagedAgentsURLMCPServerParams]?
    public var model: BetaAgentModelParam?
    public var skills: [BetaManagedAgentsSkillParams]?
    public var system: String??
    public var tools: [BetaManagedAgentsAgentToolParams]?
    public var version: Int?

    public init(
        id: String,
        mcpServers: [BetaManagedAgentsURLMCPServerParams]? = nil,
        model: BetaAgentModelParam? = nil,
        skills: [BetaManagedAgentsSkillParams]? = nil,
        system: String?? = nil,
        tools: [BetaManagedAgentsAgentToolParams]? = nil,
        version: Int? = nil
    ) {
        self.id = id
        self.mcpServers = mcpServers
        self.model = model
        self.skills = skills
        self.system = system
        self.tools = tools
        self.version = version
    }
}
