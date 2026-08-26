public struct ToolParam: Encodable, Sendable, Equatable {
    public let type = "custom"
    public let name: String
    public let inputSchema: JSONValue
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let description: String?
    public let eagerInputStreaming: Bool?
    public let inputExamples: [JSONValue]?
    public let strict: Bool?

    public init(
        name: String,
        inputSchema: JSONValue,
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        description: String? = nil,
        eagerInputStreaming: Bool? = nil,
        inputExamples: [JSONValue]? = nil,
        strict: Bool? = nil
    ) {
        self.name = name
        self.inputSchema = inputSchema
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.description = description
        self.eagerInputStreaming = eagerInputStreaming
        self.inputExamples = inputExamples
        self.strict = strict
    }
}
