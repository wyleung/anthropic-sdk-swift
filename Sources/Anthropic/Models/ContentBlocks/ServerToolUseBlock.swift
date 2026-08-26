public struct ServerToolUseBlock: Codable, Sendable, Equatable {
    public let type = "server_tool_use"
    public let id: String
    public let name: String
    public let input: JSONValue
    public let caller: Caller?

    private enum CodingKeys: String, CodingKey {
        case type, id, name, input, caller
    }

    public init(id: String, name: String, input: JSONValue, caller: Caller? = nil) {
        self.id = id
        self.name = name
        self.input = input
        self.caller = caller
    }
}
