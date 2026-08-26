import Anthropic

/// Ported from `beta_usage.py`'s `speed` field. Not present on GA's `Usage`.
public enum BetaSpeed: String, Codable, Sendable, Equatable {
    case standard
    case fast
}

/// Ported from `types/beta/beta_usage.py`. Reuses GA's `CacheCreation`, `ServerToolUsage`,
/// `OutputTokensDetails`, and `Usage.ServiceTier` directly (all confirmed field-identical to their
/// Beta counterparts). `fallbackCredit` and `iterations` are both themselves deeply-nested
/// discriminated unions in the Python source (`beta_fallback_credit_usage.py` is a 2-case union,
/// `beta_iterations_usage.py` is a 4-case union list) -- deliberately kept as raw `JSONValue`
/// passthroughs rather than fully typed, consistent with `BetaMessageCreateParams`'s
/// `contextManagement`/`diagnostics`/`fallbacks` fields.
public struct BetaUsage: Codable, Sendable, Equatable {
    public let cacheCreation: CacheCreation?
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let fallbackCredit: JSONValue?
    public let inferenceGeo: String?
    public let inputTokens: Int
    public let iterations: JSONValue?
    public let outputTokens: Int
    public let outputTokensDetails: OutputTokensDetails?
    public let serverToolUse: ServerToolUsage?
    public let serviceTier: Usage.ServiceTier?
    public let speed: BetaSpeed?
}
