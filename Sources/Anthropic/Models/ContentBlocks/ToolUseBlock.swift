public struct ToolUseBlock: Codable, Sendable, Equatable {
    public let type = "tool_use"
    public let id: String
    public let name: String
    public let input: JSONValue
    public let caller: Caller?
    public let toolsetName: String?

    private enum CodingKeys: String, CodingKey {
        case type, id, name, input, caller, toolsetName
    }

    public init(id: String, name: String, input: JSONValue, caller: Caller? = nil, toolsetName: String? = nil) {
        self.id = id
        self.name = name
        self.input = input
        self.caller = caller
        self.toolsetName = toolsetName
    }
}
