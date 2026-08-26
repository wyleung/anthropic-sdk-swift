import Anthropic

/// Ported from `types/beta/beta_model_info.py`. Identical to `ModelInfo` except for
/// `allowedFallbackModels`, so this duplicates the type rather than reusing `ModelInfo` -- every
/// other field, including the entire `ModelCapabilities` tree, is reused directly.
public struct BetaModelInfo: Codable, Sendable, Equatable {
    public let id: String
    public let allowedFallbackModels: [String]?
    public let capabilities: ModelCapabilities?
    public let createdAt: String
    public let displayName: String
    public let maxInputTokens: Int?
    public let maxTokens: Int?
    public let type: String
}
