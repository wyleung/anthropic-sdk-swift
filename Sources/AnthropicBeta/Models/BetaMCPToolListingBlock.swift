import Anthropic

/// One tool in an MCP server's listing. Ported from `types/beta/beta_mcp_tool.py`.
public struct BetaMCPTool: Codable, Sendable, Equatable {
    public let name: String
    public let inputSchema: JSONValue
    public let description: String?
}

/// The tool listing the server fetched from an MCP server while producing a response. Send the
/// assistant message back unchanged, this block included, so later requests use this listing instead of
/// asking the MCP server again. Ported from `types/beta/beta_mcp_tool_listing_block.py`.
public struct BetaMCPToolListingBlock: Codable, Sendable, Equatable {
    public let type = "mcp_tool_listing"
    public let mcpServerName: String
    public let tools: [BetaMCPTool]

    private enum CodingKeys: String, CodingKey {
        case type, mcpServerName, tools
    }
}
