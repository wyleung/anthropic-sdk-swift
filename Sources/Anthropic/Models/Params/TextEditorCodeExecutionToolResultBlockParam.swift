public struct TextEditorCodeExecutionViewResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "text_editor_code_execution_view_result"
    public let content: String
    public let fileType: String
    public let numLines: Int?
    public let startLine: Int?
    public let totalLines: Int?

    public init(
        content: String,
        fileType: String,
        numLines: Int? = nil,
        startLine: Int? = nil,
        totalLines: Int? = nil
    ) {
        self.content = content
        self.fileType = fileType
        self.numLines = numLines
        self.startLine = startLine
        self.totalLines = totalLines
    }
}

public struct TextEditorCodeExecutionCreateResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "text_editor_code_execution_create_result"
    public let isFileUpdate: Bool

    public init(isFileUpdate: Bool) {
        self.isFileUpdate = isFileUpdate
    }
}

public struct TextEditorCodeExecutionStrReplaceResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "text_editor_code_execution_str_replace_result"
    public let lines: [String]?
    public let newLines: Int?
    public let newStart: Int?
    public let oldLines: Int?
    public let oldStart: Int?

    public init(
        lines: [String]? = nil,
        newLines: Int? = nil,
        newStart: Int? = nil,
        oldLines: Int? = nil,
        oldStart: Int? = nil
    ) {
        self.lines = lines
        self.newLines = newLines
        self.newStart = newStart
        self.oldLines = oldLines
        self.oldStart = oldStart
    }
}

public struct TextEditorCodeExecutionToolResultErrorParam: Encodable, Sendable, Equatable {
    public let type = "text_editor_code_execution_tool_result_error"
    public let errorCode: String
    public let errorMessage: String?

    public init(errorCode: String, errorMessage: String? = nil) {
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public enum TextEditorCodeExecutionToolResultBlockParamContentParam: Sendable, Equatable {
    case error(TextEditorCodeExecutionToolResultErrorParam)
    case view(TextEditorCodeExecutionViewResultBlockParam)
    case create(TextEditorCodeExecutionCreateResultBlockParam)
    case strReplace(TextEditorCodeExecutionStrReplaceResultBlockParam)
}

extension TextEditorCodeExecutionToolResultBlockParamContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .error(let value): try container.encode(value)
        case .view(let value): try container.encode(value)
        case .create(let value): try container.encode(value)
        case .strReplace(let value): try container.encode(value)
        }
    }
}

public struct TextEditorCodeExecutionToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "text_editor_code_execution_tool_result"
    public let toolUseId: String
    public let content: TextEditorCodeExecutionToolResultBlockParamContentParam
    public let cacheControl: CacheControlEphemeral?

    public init(
        toolUseId: String,
        content: TextEditorCodeExecutionToolResultBlockParamContentParam,
        cacheControl: CacheControlEphemeral? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.cacheControl = cacheControl
    }
}
