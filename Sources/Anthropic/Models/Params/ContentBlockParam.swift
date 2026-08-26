public enum ContentBlockParam: Sendable, Equatable {
    case text(TextBlockParam)
    case image(ImageBlockParam)
    case document(DocumentBlockParam)
    case searchResult(SearchResultBlockParam)
    case thinking(ThinkingBlockParam)
    case redactedThinking(RedactedThinkingBlockParam)
    case toolUse(ToolUseBlockParam)
    case toolResult(ToolResultBlockParam)
    case serverToolUse(ServerToolUseBlockParam)
    case webSearchToolResult(WebSearchToolResultBlockParam)
    case webFetchToolResult(WebFetchToolResultBlockParam)
    case codeExecutionToolResult(CodeExecutionToolResultBlockParam)
    case bashCodeExecutionToolResult(BashCodeExecutionToolResultBlockParam)
    case textEditorCodeExecutionToolResult(TextEditorCodeExecutionToolResultBlockParam)
    case toolSearchToolResult(ToolSearchToolResultBlockParam)
    case containerUpload(ContainerUploadBlockParam)
}

extension ContentBlockParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .document(let value): try value.encode(to: encoder)
        case .searchResult(let value): try value.encode(to: encoder)
        case .thinking(let value): try value.encode(to: encoder)
        case .redactedThinking(let value): try value.encode(to: encoder)
        case .toolUse(let value): try value.encode(to: encoder)
        case .toolResult(let value): try value.encode(to: encoder)
        case .serverToolUse(let value): try value.encode(to: encoder)
        case .webSearchToolResult(let value): try value.encode(to: encoder)
        case .webFetchToolResult(let value): try value.encode(to: encoder)
        case .codeExecutionToolResult(let value): try value.encode(to: encoder)
        case .bashCodeExecutionToolResult(let value): try value.encode(to: encoder)
        case .textEditorCodeExecutionToolResult(let value): try value.encode(to: encoder)
        case .toolSearchToolResult(let value): try value.encode(to: encoder)
        case .containerUpload(let value): try value.encode(to: encoder)
        }
    }
}
