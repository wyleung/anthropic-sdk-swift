import Anthropic

/// Cumulative token usage for the dream across every pipeline stage. Ported from
/// `beta_dream_usage.py` -- all 4 fields are required (unlike `Message.usage`, where cache fields
/// are optional).
public struct BetaDreamUsage: Codable, Sendable, Equatable {
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int

    public init(
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int,
        inputTokens: Int,
        outputTokens: Int
    ) {
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
