/// What context management did to a counted request. Ported from
/// `types/beta/beta_count_tokens_context_management_response.py`.
public struct BetaCountTokensContextManagementResponse: Codable, Sendable, Equatable {
    /// The original token count before context management was applied.
    public let originalInputTokens: Int
}

/// The result of `beta.messages.countTokens`. Ported from `types/beta/beta_message_tokens_count.py`.
public struct BetaMessageTokensCount: Codable, Sendable, Equatable {
    /// Information about context management applied to the message; `nil` when none was.
    public let contextManagement: BetaCountTokensContextManagementResponse?
    /// The total number of tokens across the provided list of messages, system prompt, and tools.
    public let inputTokens: Int
}
