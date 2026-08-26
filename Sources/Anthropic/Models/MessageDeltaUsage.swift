public struct MessageDeltaUsage: Codable, Sendable, Equatable {
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let inputTokens: Int?
    public let outputTokens: Int
    public let outputTokensDetails: OutputTokensDetails?
    public let serverToolUse: ServerToolUsage?
}
