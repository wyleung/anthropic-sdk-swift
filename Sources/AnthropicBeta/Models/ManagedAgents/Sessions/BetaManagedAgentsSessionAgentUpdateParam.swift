import Anthropic

/// Overrides applied to a running session's agent via `client.beta.sessions.update`. Ported from
/// `beta_managed_agents_session_agent_update_param.py`. Both fields are plain full-replacement
/// arrays (omit to leave unchanged, empty array clears) -- neither docstring documents a tri-state
/// clear/omit distinction, so no `T??` fields here (contrast
/// `BetaManagedAgentsAgentWithOverridesParams.system`).
public struct BetaManagedAgentsSessionAgentUpdateParam: Encodable, Sendable, Equatable {
    public var mcpServers: [BetaManagedAgentsURLMCPServerParams]?
    public var tools: [BetaManagedAgentsAgentToolParams]?

    public init(
        mcpServers: [BetaManagedAgentsURLMCPServerParams]? = nil,
        tools: [BetaManagedAgentsAgentToolParams]? = nil
    ) {
        self.mcpServers = mcpServers
        self.tools = tools
    }
}
