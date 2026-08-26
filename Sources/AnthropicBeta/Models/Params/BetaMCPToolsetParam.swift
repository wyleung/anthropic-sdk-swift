import Anthropic

/// Ported from `types/beta/beta_mcp_toolset_param.py`. Configures enabled/defer-loading for every
/// tool from an MCP server at once, with optional per-tool overrides via `configs`.
public struct BetaMCPToolsetParam: Encodable, Sendable, Equatable {
    public let mcpServerName: String
    public let type = "mcp_toolset"
    public let cacheControl: CacheControlEphemeral?
    public let configs: [String: BetaMCPToolConfigParam]?
    public let defaultConfig: BetaMCPToolDefaultConfigParam?

    public init(
        mcpServerName: String,
        cacheControl: CacheControlEphemeral? = nil,
        configs: [String: BetaMCPToolConfigParam]? = nil,
        defaultConfig: BetaMCPToolDefaultConfigParam? = nil
    ) {
        self.mcpServerName = mcpServerName
        self.cacheControl = cacheControl
        self.configs = configs
        self.defaultConfig = defaultConfig
    }
}
