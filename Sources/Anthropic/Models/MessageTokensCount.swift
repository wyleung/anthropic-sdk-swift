/// The result of `messages.countTokens`. Ported from `types/message_tokens_count.py`.
public struct MessageTokensCount: Codable, Sendable, Equatable {
    /// The total number of tokens across the provided list of messages, system prompt, and tools.
    public let inputTokens: Int
}
