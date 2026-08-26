import Anthropic

/// Ported from `types/beta/beta_mcp_tool_use_block.py`. `input` is Python's `Dict[str, object]`.
public struct BetaMCPToolUseBlock: Codable, Sendable, Equatable {
    public let id: String
    public let input: [String: JSONValue]
    public let name: String
    public let serverName: String
    public let type = "mcp_tool_use"

    public init(id: String, input: [String: JSONValue], name: String, serverName: String) {
        self.id = id
        self.input = input
        self.name = name
        self.serverName = serverName
    }

    private enum CodingKeys: String, CodingKey {
        case id, input, name, serverName, type
    }
}
