import Anthropic

/// Ported from `types/beta/beta_mcp_toolset_param.py`. Configures enabled/defer-loading for every
/// tool from an MCP server at once, with optional per-tool overrides via `configs`.
public struct BetaMCPToolsetParam: Encodable, Sendable, Equatable {
    public let mcpServerName: String
    public let type = "mcp_toolset"
    public let cacheControl: CacheControlEphemeral?
    public let configs: [String: BetaMCPToolConfigParam]?
    public let defaultConfig: BetaMCPToolDefaultConfigParam?
    public let tools: [BetaMCPToolParam]?

    /// - Parameter tools: The server's tool listing, pinned: when present, the server is not asked for
    ///   its tools before sampling, and exactly these entries -- with `defaultConfig` and `configs`
    ///   applied -- are the toolset's tools. Copy it from the `mcp_tool_listing` block of an earlier
    ///   response.
    public init(
        mcpServerName: String,
        cacheControl: CacheControlEphemeral? = nil,
        configs: [String: BetaMCPToolConfigParam]? = nil,
        defaultConfig: BetaMCPToolDefaultConfigParam? = nil,
        tools: [BetaMCPToolParam]? = nil
    ) {
        self.mcpServerName = mcpServerName
        self.cacheControl = cacheControl
        self.configs = configs
        self.defaultConfig = defaultConfig
        self.tools = tools
    }
}
