public struct ToolUseBlockParam: Encodable, Sendable, Equatable {
    public let type = "tool_use"
    public let id: String
    public let name: String
    public let input: JSONValue
    public let cacheControl: CacheControlEphemeral?
    public let caller: CallerParam?
    public let toolsetName: String?

    public init(
        id: String,
        name: String,
        input: JSONValue,
        cacheControl: CacheControlEphemeral? = nil,
        caller: CallerParam? = nil,
        toolsetName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.cacheControl = cacheControl
        self.caller = caller
        self.toolsetName = toolsetName
    }
}
