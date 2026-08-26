public struct ThinkingBlock: Codable, Sendable, Equatable {
    public let type = "thinking"
    public let thinking: String
    public let signature: String

    private enum CodingKeys: String, CodingKey {
        case type, thinking, signature
    }

    public init(thinking: String, signature: String) {
        self.thinking = thinking
        self.signature = signature
    }
}

public struct RedactedThinkingBlock: Codable, Sendable, Equatable {
    public let type = "redacted_thinking"
    public let data: String

    private enum CodingKeys: String, CodingKey {
        case type, data
    }
}
