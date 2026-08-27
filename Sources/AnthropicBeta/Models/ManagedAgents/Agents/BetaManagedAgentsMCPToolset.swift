import Anthropic

/// Per-tool override within an MCP toolset, as returned in a response. Ported from
/// `beta_managed_agents_mcp_tool_config.py`.
public struct BetaManagedAgentsMCPToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy

    public init(enabled: Bool, name: String, permissionPolicy: BetaManagedAgentsPermissionPolicy) {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
    }
}

/// The resolved fallback applied to any MCP tool not covered by `configs`. Always present on a
/// response, unlike the params side where it's optional. Ported from
/// `beta_managed_agents_mcp_toolset_default_config.py`.
public struct BetaManagedAgentsMCPToolsetDefaultConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy

    public init(enabled: Bool, permissionPolicy: BetaManagedAgentsPermissionPolicy) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// A tool coming from an external MCP server, as returned in a `BetaManagedAgentsAgent` response.
/// Ported from `beta_managed_agents_mcp_toolset.py`.
public struct BetaManagedAgentsMCPToolset: Codable, Sendable, Equatable {
    public let configs: [BetaManagedAgentsMCPToolConfig]
    public let defaultConfig: BetaManagedAgentsMCPToolsetDefaultConfig
    public let mcpServerName: String
    public let type: String

    public init(
        configs: [BetaManagedAgentsMCPToolConfig],
        defaultConfig: BetaManagedAgentsMCPToolsetDefaultConfig,
        mcpServerName: String,
        type: String = "mcp_toolset"
    ) {
        self.configs = configs
        self.defaultConfig = defaultConfig
        self.mcpServerName = mcpServerName
        self.type = type
    }
}

/// Ported from `beta_managed_agents_mcp_tool_config_params.py`. `enabled`/`permissionPolicy` are
/// optional overrides -- omit to fall back to the toolset's `defaultConfig`.
public struct BetaManagedAgentsMCPToolConfigParams: Encodable, Sendable, Equatable {
    public let name: String
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(name: String, enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.name = name
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_mcp_toolset_default_config_params.py`. Optional -- omit to let
/// the server apply its own default.
public struct BetaManagedAgentsMCPToolsetDefaultConfigParams: Encodable, Sendable, Equatable {
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_mcp_toolset_params.py`.
public struct BetaManagedAgentsMCPToolsetParams: Encodable, Sendable, Equatable {
    public let mcpServerName: String
    public let type = "mcp_toolset"
    public let configs: [BetaManagedAgentsMCPToolConfigParams]?
    public let defaultConfig: BetaManagedAgentsMCPToolsetDefaultConfigParams?

    public init(
        mcpServerName: String,
        configs: [BetaManagedAgentsMCPToolConfigParams]? = nil,
        defaultConfig: BetaManagedAgentsMCPToolsetDefaultConfigParams? = nil
    ) {
        self.mcpServerName = mcpServerName
        self.configs = configs
        self.defaultConfig = defaultConfig
    }
}
