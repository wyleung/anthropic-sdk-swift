import Anthropic

/// Ported from `types/beta/beta_refusal_stop_details.py`. Adds three fallback/retry-oriented
/// fields beyond GA's `RefusalStopDetails`, so this duplicates the type rather than reusing it.
/// Reuses GA's `RefusalCategory`, which is field-identical.
public struct BetaRefusalStopDetails: Codable, Sendable, Equatable {
    public let type = "refusal"
    public let category: RefusalCategory?
    public let explanation: String?
    public let fallbackCreditToken: String?
    public let fallbackHasPrefillClaim: Bool?
    public let recommendedModel: String?

    private enum CodingKeys: String, CodingKey {
        case type, category, explanation, fallbackCreditToken, fallbackHasPrefillClaim, recommendedModel
    }
}
