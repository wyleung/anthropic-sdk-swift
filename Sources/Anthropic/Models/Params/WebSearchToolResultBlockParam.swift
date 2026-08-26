public struct WebSearchResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "web_search_result"
    public let title: String
    public let url: String
    public let encryptedContent: String
    public let pageAge: String?

    public init(title: String, url: String, encryptedContent: String, pageAge: String? = nil) {
        self.title = title
        self.url = url
        self.encryptedContent = encryptedContent
        self.pageAge = pageAge
    }
}

public struct WebSearchToolRequestErrorParam: Encodable, Sendable, Equatable {
    public let type = "web_search_tool_result_error"
    public let errorCode: String

    public init(errorCode: String) {
        self.errorCode = errorCode
    }
}

public enum WebSearchToolResultBlockParamContentParam: Sendable, Equatable {
    case results([WebSearchResultBlockParam])
    case error(WebSearchToolRequestErrorParam)
}

extension WebSearchToolResultBlockParamContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .results(let value): try container.encode(value)
        case .error(let value): try container.encode(value)
        }
    }
}

public struct WebSearchToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "web_search_tool_result"
    public let toolUseId: String
    public let content: WebSearchToolResultBlockParamContentParam
    public let cacheControl: CacheControlEphemeral?
    public let caller: CallerParam?

    public init(
        toolUseId: String,
        content: WebSearchToolResultBlockParamContentParam,
        cacheControl: CacheControlEphemeral? = nil,
        caller: CallerParam? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.cacheControl = cacheControl
        self.caller = caller
    }
}
