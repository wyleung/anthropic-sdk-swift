public struct ToolSearchToolResultErrorParam: Encodable, Sendable, Equatable {
    public let type = "tool_search_tool_result_error"
    public let errorCode: String
    public let errorMessage: String?

    public init(errorCode: String, errorMessage: String? = nil) {
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public struct ToolSearchToolSearchResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "tool_search_tool_search_result"
    public let toolReferences: [ToolReferenceBlockParam]

    public init(toolReferences: [ToolReferenceBlockParam]) {
        self.toolReferences = toolReferences
    }
}

public enum ToolSearchToolResultBlockParamContentParam: Sendable, Equatable {
    case error(ToolSearchToolResultErrorParam)
    case searchResult(ToolSearchToolSearchResultBlockParam)
}

extension ToolSearchToolResultBlockParamContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .error(let value): try container.encode(value)
        case .searchResult(let value): try container.encode(value)
        }
    }
}

public struct ToolSearchToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "tool_search_tool_result"
    public let toolUseId: String
    public let content: ToolSearchToolResultBlockParamContentParam
    public let cacheControl: CacheControlEphemeral?

    public init(
        toolUseId: String,
        content: ToolSearchToolResultBlockParamContentParam,
        cacheControl: CacheControlEphemeral? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.cacheControl = cacheControl
    }
}
