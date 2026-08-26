public struct TextEditorCodeExecutionViewResultBlock: Codable, Sendable, Equatable {
    public let type = "text_editor_code_execution_view_result"
    public let content: String
    public let fileType: String
    public let numLines: Int?
    public let startLine: Int?
    public let totalLines: Int?

    private enum CodingKeys: String, CodingKey {
        case type, content, fileType, numLines, startLine, totalLines
    }
}

public struct TextEditorCodeExecutionCreateResultBlock: Codable, Sendable, Equatable {
    public let type = "text_editor_code_execution_create_result"
    public let isFileUpdate: Bool

    private enum CodingKeys: String, CodingKey {
        case type, isFileUpdate
    }
}

public struct TextEditorCodeExecutionStrReplaceResultBlock: Codable, Sendable, Equatable {
    public let type = "text_editor_code_execution_str_replace_result"
    public let lines: [String]?
    public let newLines: Int?
    public let newStart: Int?
    public let oldLines: Int?
    public let oldStart: Int?

    private enum CodingKeys: String, CodingKey {
        case type, lines, newLines, newStart, oldLines, oldStart
    }
}

public struct TextEditorCodeExecutionToolResultError: Codable, Sendable, Equatable {
    public let type = "text_editor_code_execution_tool_result_error"
    public let errorCode: String
    public let errorMessage: String?

    private enum CodingKeys: String, CodingKey {
        case type, errorCode, errorMessage
    }
}

public enum TextEditorCodeExecutionToolResultContent: Sendable, Equatable {
    case view(TextEditorCodeExecutionViewResultBlock)
    case create(TextEditorCodeExecutionCreateResultBlock)
    case strReplace(TextEditorCodeExecutionStrReplaceResultBlock)
    case error(TextEditorCodeExecutionToolResultError)
    case unknown(type: String, raw: JSONValue)
}

extension TextEditorCodeExecutionToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "text_editor_code_execution_view_result":
            self = .view(try TextEditorCodeExecutionViewResultBlock(from: decoder))
        case "text_editor_code_execution_create_result":
            self = .create(try TextEditorCodeExecutionCreateResultBlock(from: decoder))
        case "text_editor_code_execution_str_replace_result":
            self = .strReplace(try TextEditorCodeExecutionStrReplaceResultBlock(from: decoder))
        case "text_editor_code_execution_tool_result_error":
            self = .error(try TextEditorCodeExecutionToolResultError(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .view(let value): try value.encode(to: encoder)
        case .create(let value): try value.encode(to: encoder)
        case .strReplace(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

public struct TextEditorCodeExecutionToolResultBlock: Codable, Sendable, Equatable {
    public let type = "text_editor_code_execution_tool_result"
    public let toolUseId: String
    public let content: TextEditorCodeExecutionToolResultContent

    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content
    }
}
