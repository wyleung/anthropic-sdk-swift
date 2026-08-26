public struct ThinkingBlockParam: Encodable, Sendable, Equatable {
    public let type = "thinking"
    public let signature: String
    public let thinking: String

    public init(signature: String, thinking: String) {
        self.signature = signature
        self.thinking = thinking
    }
}

public struct RedactedThinkingBlockParam: Encodable, Sendable, Equatable {
    public let type = "redacted_thinking"
    public let data: String

    public init(data: String) {
        self.data = data
    }
}
