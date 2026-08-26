public struct ToolSearchToolBm25_20251119Param: Encodable, Sendable, Equatable {
    public let name = "tool_search_tool_bm25"
    public let type = "tool_search_tool_bm25_20251119"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.strict = strict
    }
}

public struct ToolSearchToolRegex20251119Param: Encodable, Sendable, Equatable {
    public let name = "tool_search_tool_regex"
    public let type = "tool_search_tool_regex_20251119"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.strict = strict
    }
}
