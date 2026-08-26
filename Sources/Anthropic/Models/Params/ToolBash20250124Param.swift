public struct ToolBash20250124Param: Encodable, Sendable, Equatable {
    public let name = "bash"
    public let type = "bash_20250124"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let inputExamples: [JSONValue]?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        inputExamples: [JSONValue]? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.inputExamples = inputExamples
        self.strict = strict
    }
}
