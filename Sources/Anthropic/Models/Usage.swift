public struct Usage: Codable, Sendable, Equatable {
    public enum ServiceTier: String, Codable, Sendable, Equatable {
        case standard
        case priority
        case batch
    }

    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreation: CacheCreation?
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let inferenceGeo: String?
    public let outputTokensDetails: OutputTokensDetails?
    public let serverToolUse: ServerToolUsage?
    public let serviceTier: ServiceTier?
}
