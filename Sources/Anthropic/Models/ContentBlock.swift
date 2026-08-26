/// A block of assistant-generated content. Ported from `types/content_block.py`'s 12-case
/// discriminated union. Every case not yet modeled, or not recognized by this port's version,
/// decodes into `.unknown` rather than failing.
public enum ContentBlock: Sendable, Equatable {
    case text(TextBlock)
    case thinking(ThinkingBlock)
    case redactedThinking(RedactedThinkingBlock)
    case toolUse(ToolUseBlock)
    case serverToolUse(ServerToolUseBlock)
    case webSearchToolResult(WebSearchToolResultBlock)
    case webFetchToolResult(WebFetchToolResultBlock)
    case codeExecutionToolResult(CodeExecutionToolResultBlock)
    case bashCodeExecutionToolResult(BashCodeExecutionToolResultBlock)
    case textEditorCodeExecutionToolResult(TextEditorCodeExecutionToolResultBlock)
    case toolSearchToolResult(ToolSearchToolResultBlock)
    case containerUpload(ContainerUploadBlock)
    case unknown(type: String, raw: JSONValue)
}

extension ContentBlock: Codable {
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
        case "code_execution_tool_result":
            self = .codeExecutionToolResult(try CodeExecutionToolResultBlock(from: decoder))
        case "bash_code_execution_tool_result":
            self = .bashCodeExecutionToolResult(try BashCodeExecutionToolResultBlock(from: decoder))
        case "text_editor_code_execution_tool_result":
            self = .textEditorCodeExecutionToolResult(
                try TextEditorCodeExecutionToolResultBlock(from: decoder))
        case "tool_search_tool_result":
            self = .toolSearchToolResult(try ToolSearchToolResultBlock(from: decoder))
        case "container_upload":
            self = .containerUpload(try ContainerUploadBlock(from: decoder))
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
        case .codeExecutionToolResult(let block): try block.encode(to: encoder)
        case .bashCodeExecutionToolResult(let block): try block.encode(to: encoder)
        case .textEditorCodeExecutionToolResult(let block): try block.encode(to: encoder)
        case .toolSearchToolResult(let block): try block.encode(to: encoder)
        case .containerUpload(let block): try block.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
