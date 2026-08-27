import Anthropic

/// The resolved fallback applied to any built-in tool not covered by `configs`. Always present on
/// a response. Ported from `beta_managed_agents_agent_toolset_default_config.py`.
public struct BetaManagedAgentsAgentToolsetDefaultConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy

    public init(enabled: Bool, permissionPolicy: BetaManagedAgentsPermissionPolicy) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// The built-in bash/edit/glob/grep/read/write/web_fetch/web_search toolset, as returned in a
/// `BetaManagedAgentsAgent` response. Ported from `beta_managed_agents_agent_toolset20260401.py`.
public struct BetaManagedAgentsAgentToolset20260401: Codable, Sendable, Equatable {
    public let configs: [BetaManagedAgentsAgentToolConfig]
    public let defaultConfig: BetaManagedAgentsAgentToolsetDefaultConfig
    public let type: String

    public init(
        configs: [BetaManagedAgentsAgentToolConfig],
        defaultConfig: BetaManagedAgentsAgentToolsetDefaultConfig,
        type: String = "agent_toolset_20260401"
    ) {
        self.configs = configs
        self.defaultConfig = defaultConfig
        self.type = type
    }
}

/// Ported from `beta_managed_agents_agent_toolset_default_config_params.py`. Optional -- omit to
/// let the server apply its own default.
public struct BetaManagedAgentsAgentToolsetDefaultConfigParams: Encodable, Sendable, Equatable {
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_agent_toolset20260401_params.py`.
public struct BetaManagedAgentsAgentToolset20260401Params: Encodable, Sendable, Equatable {
    public let type = "agent_toolset_20260401"
    public let configs: [BetaManagedAgentsAgentToolConfigParams]?
    public let defaultConfig: BetaManagedAgentsAgentToolsetDefaultConfigParams?

    public init(
        configs: [BetaManagedAgentsAgentToolConfigParams]? = nil,
        defaultConfig: BetaManagedAgentsAgentToolsetDefaultConfigParams? = nil
    ) {
        self.configs = configs
        self.defaultConfig = defaultConfig
    }
}
