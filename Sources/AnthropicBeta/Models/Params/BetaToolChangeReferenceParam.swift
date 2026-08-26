/// Ported from the `Tool` type alias shared by `beta_request_tool_removal_block_param.py` and
/// `beta_request_tool_addition_block_param.py`: a reference to the tool being surfaced/withdrawn,
/// by name (`tool_reference`), by MCP server+tool name (`mcp_tool_reference`), or to an entire MCP
/// server's toolset (`mcp_toolset_reference`).
public enum BetaToolChangeReferenceParam: Sendable, Equatable {
    case tool(BetaToolChangeToolReferenceParam)
    case mcpTool(BetaToolChangeMCPToolReferenceParam)
    case mcpToolset(BetaToolChangeMCPToolsetReferenceParam)
}

extension BetaToolChangeReferenceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tool(let value): try value.encode(to: encoder)
        case .mcpTool(let value): try value.encode(to: encoder)
        case .mcpToolset(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/beta_tool_change_tool_reference_param.py`. References a tool the caller
/// declared directly in `tools[]` by name -- not the composed `{server}_{name}` form the server
/// assigns to MCP-resolved tools.
public struct BetaToolChangeToolReferenceParam: Encodable, Sendable, Equatable {
    public let name: String
    public let type = "tool_reference"

    public init(name: String) {
        self.name = name
    }
}

/// Ported from `types/beta/beta_tool_change_mcp_tool_reference_param.py`. References a single MCP
/// tool by the same `server_name`/`name` pair `mcp_tool_use` carries.
public struct BetaToolChangeMCPToolReferenceParam: Encodable, Sendable, Equatable {
    public let name: String
    public let serverName: String
    public let type = "mcp_tool_reference"

    public init(name: String, serverName: String) {
        self.name = name
        self.serverName = serverName
    }
}

/// Ported from `types/beta/beta_tool_change_mcp_toolset_reference_param.py`. References every tool
/// in the named MCP server's toolset.
public struct BetaToolChangeMCPToolsetReferenceParam: Encodable, Sendable, Equatable {
    public let serverName: String
    public let type = "mcp_toolset_reference"

    public init(serverName: String) {
        self.serverName = serverName
    }
}
