import Anthropic

/// Ported from `types/beta/beta_content_block.py`'s 17-case discriminated union. Twelve members are
/// confirmed field-identical to their GA `ContentBlock` counterparts and reuse GA's leaf structs
/// directly; the remaining five (`compaction`, `fallback`, `mcp_tool_use`, `mcp_tool_result`,
/// `advisor_tool_result`) have no GA equivalent at all and get dedicated Beta-only payload types.
/// This supersedes slice 1's `BetaContentBlock = ContentBlock` typealias, which relied on GA's
/// `.unknown` fallback to absorb those five kinds as raw JSON -- now they decode typed.
public enum BetaContentBlock: Sendable, Equatable {
    case text(TextBlock)
    case thinking(ThinkingBlock)
    case redactedThinking(RedactedThinkingBlock)
    case toolUse(ToolUseBlock)
    case serverToolUse(ServerToolUseBlock)
    case webSearchToolResult(WebSearchToolResultBlock)
    case webFetchToolResult(WebFetchToolResultBlock)
    case advisorToolResult(BetaAdvisorToolResultBlock)
    case codeExecutionToolResult(CodeExecutionToolResultBlock)
    case bashCodeExecutionToolResult(BashCodeExecutionToolResultBlock)
    case textEditorCodeExecutionToolResult(TextEditorCodeExecutionToolResultBlock)
    case toolSearchToolResult(ToolSearchToolResultBlock)
    case mcpToolUse(BetaMCPToolUseBlock)
    case mcpToolResult(BetaMCPToolResultBlock)
    case containerUpload(ContainerUploadBlock)
    case compaction(BetaCompactionBlock)
    case fallback(BetaFallbackBlock)
    case unknown(type: String, raw: JSONValue)
}

extension BetaContentBlock: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        case "redacted_thinking":
            self = .redactedThinking(try RedactedThinkingBlock(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "server_tool_use":
            self = .serverToolUse(try ServerToolUseBlock(from: decoder))
        case "web_search_tool_result":
            self = .webSearchToolResult(try WebSearchToolResultBlock(from: decoder))
        case "web_fetch_tool_result":
            self = .webFetchToolResult(try WebFetchToolResultBlock(from: decoder))
        case "advisor_tool_result":
            self = .advisorToolResult(try BetaAdvisorToolResultBlock(from: decoder))
        case "code_execution_tool_result":
            self = .codeExecutionToolResult(try CodeExecutionToolResultBlock(from: decoder))
        case "bash_code_execution_tool_result":
            self = .bashCodeExecutionToolResult(try BashCodeExecutionToolResultBlock(from: decoder))
        case "text_editor_code_execution_tool_result":
            self = .textEditorCodeExecutionToolResult(
                try TextEditorCodeExecutionToolResultBlock(from: decoder))
        case "tool_search_tool_result":
            self = .toolSearchToolResult(try ToolSearchToolResultBlock(from: decoder))
        case "mcp_tool_use":
            self = .mcpToolUse(try BetaMCPToolUseBlock(from: decoder))
        case "mcp_tool_result":
            self = .mcpToolResult(try BetaMCPToolResultBlock(from: decoder))
        case "container_upload":
            self = .containerUpload(try ContainerUploadBlock(from: decoder))
        case "compaction":
            self = .compaction(try BetaCompactionBlock(from: decoder))
        case "fallback":
            self = .fallback(try BetaFallbackBlock(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block): try block.encode(to: encoder)
        case .thinking(let block): try block.encode(to: encoder)
        case .redactedThinking(let block): try block.encode(to: encoder)
        case .toolUse(let block): try block.encode(to: encoder)
        case .serverToolUse(let block): try block.encode(to: encoder)
        case .webSearchToolResult(let block): try block.encode(to: encoder)
        case .webFetchToolResult(let block): try block.encode(to: encoder)
        case .advisorToolResult(let block): try block.encode(to: encoder)
        case .codeExecutionToolResult(let block): try block.encode(to: encoder)
        case .bashCodeExecutionToolResult(let block): try block.encode(to: encoder)
        case .textEditorCodeExecutionToolResult(let block): try block.encode(to: encoder)
        case .toolSearchToolResult(let block): try block.encode(to: encoder)
        case .mcpToolUse(let block): try block.encode(to: encoder)
        case .mcpToolResult(let block): try block.encode(to: encoder)
        case .containerUpload(let block): try block.encode(to: encoder)
        case .compaction(let block): try block.encode(to: encoder)
        case .fallback(let block): try block.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
