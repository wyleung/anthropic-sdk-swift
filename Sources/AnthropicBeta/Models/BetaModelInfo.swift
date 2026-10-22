import Anthropic

/// Ported from `types/beta/beta_model_info.py`. `ModelInfo` plus `allowedFallbackModels`, with
/// `BetaModelCapabilities` in place of GA's capabilities (they add `compaction`). The lifecycle fields
/// reuse GA's `ModelLifecycle`/`ModelLine` and are optional for the same reason as on `ModelInfo`: they
/// postdate this port, so a payload without them must still decode.
public struct BetaModelInfo: Codable, Sendable, Equatable {
    public let id: String
    public let allowedFallbackModels: [String]?
    public let capabilities: BetaModelCapabilities?
    public let createdAt: String
    /// When the model was most recently deprecated; `nil` while `active`.
    public let deprecatedAt: String?
    public let displayName: String
    /// The model's current lifecycle stage; this, not `retiresAt`, is the retirement signal.
    public let lifecycle: ModelLifecycle?
    public let line: ModelLine?
    public let maxInputTokens: Int?
    public let maxTokens: Int?
    /// The currently scheduled retirement date; `nil` while `active` or when none is scheduled.
    public let retiresAt: String?
    public let type: String
}
