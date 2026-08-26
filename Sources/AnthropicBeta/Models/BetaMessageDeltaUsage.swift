import Anthropic

/// Ported from `types/beta/beta_message_delta_usage.py`. Reuses GA's `OutputTokensDetails` and
/// `ServerToolUsage` directly (confirmed field-identical), matching `BetaUsage`'s convention.
/// `fallbackCredit` and `iterations` are raw `JSONValue` passthroughs, each a deeply-nested union
/// in the Python source, also matching `BetaUsage`'s treatment of the same two fields.
public struct BetaMessageDeltaUsage: Codable, Sendable, Equatable {
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let fallbackCredit: JSONValue?
    public let inputTokens: Int?
    public let iterations: JSONValue?
    public let outputTokens: Int
    public let outputTokensDetails: OutputTokensDetails?
    public let serverToolUse: ServerToolUsage?
}
