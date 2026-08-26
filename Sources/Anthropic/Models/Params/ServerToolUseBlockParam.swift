public struct ServerToolUseBlockParam: Encodable, Sendable, Equatable {
    public let type = "server_tool_use"
    public let id: String
    public let name: String
    public let input: JSONValue
    public let cacheControl: CacheControlEphemeral?
    public let caller: CallerParam?

    public init(
        id: String,
        name: String,
        input: JSONValue,
        cacheControl: CacheControlEphemeral? = nil,
        caller: CallerParam? = nil
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.cacheControl = cacheControl
        self.caller = caller
    }
}
