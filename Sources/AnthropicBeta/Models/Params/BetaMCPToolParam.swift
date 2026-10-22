import Anthropic

/// One MCP tool as pinned in a toolset's `tools` list or sent back in a `mcp_tool_listing` block.
/// Ported from `types/beta/beta_mcp_tool_param_param.py` (`BetaMCPToolParamParam` upstream -- the doubled
/// name is a codegen artifact).
public struct BetaMCPToolParam: Encodable, Sendable, Equatable {
    public let name: String
    public let inputSchema: JSONValue
    public let description: String?

    public init(name: String, inputSchema: JSONValue, description: String? = nil) {
        self.name = name
        self.inputSchema = inputSchema
        self.description = description
    }
}

/// An MCP server's tool listing, sent back so later requests use it instead of asking the server again.
/// Ported from `types/beta/beta_mcp_tool_listing_block_param.py`. Normally produced by converting a
/// response `BetaMCPToolListingBlock` with `asRequestParam()`.
public struct BetaMCPToolListingBlockParam: Encodable, Sendable, Equatable {
    public let type = "mcp_tool_listing"
    public let mcpServerName: String
    public let tools: [BetaMCPToolParam]

    public init(mcpServerName: String, tools: [BetaMCPToolParam]) {
        self.mcpServerName = mcpServerName
        self.tools = tools
    }
}
