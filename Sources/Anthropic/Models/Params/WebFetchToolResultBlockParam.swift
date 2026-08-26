public struct WebFetchBlockParam: Encodable, Sendable, Equatable {
    public let type = "web_fetch_result"
    public let url: String
    public let content: DocumentBlockParam
    public let retrievedAt: String?

    public init(url: String, content: DocumentBlockParam, retrievedAt: String? = nil) {
        self.url = url
        self.content = content
        self.retrievedAt = retrievedAt
    }
}

public struct WebFetchToolResultErrorBlockParam: Encodable, Sendable, Equatable {
    public let type = "web_fetch_tool_result_error"
    public let errorCode: String

    public init(errorCode: String) {
        self.errorCode = errorCode
    }
}

public enum WebFetchToolResultBlockParamContentParam: Sendable, Equatable {
    case result(WebFetchBlockParam)
    case error(WebFetchToolResultErrorBlockParam)
}

extension WebFetchToolResultBlockParamContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .result(let value): try container.encode(value)
        case .error(let value): try container.encode(value)
        }
    }
}

public struct WebFetchToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "web_fetch_tool_result"
    public let toolUseId: String
    public let content: WebFetchToolResultBlockParamContentParam
    public let cacheControl: CacheControlEphemeral?
    public let caller: CallerParam?

    public init(
        toolUseId: String,
        content: WebFetchToolResultBlockParamContentParam,
        cacheControl: CacheControlEphemeral? = nil,
        caller: CallerParam? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.cacheControl = cacheControl
        self.caller = caller
    }
}
