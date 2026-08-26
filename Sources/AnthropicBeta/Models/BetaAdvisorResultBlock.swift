/// Ported from `types/beta/beta_advisor_result_block.py`. `stopReason` mirrors the top-level
/// message `stop_reason` values but is documented as a plain string, not `BetaStopReason`.
public struct BetaAdvisorResultBlock: Codable, Sendable, Equatable {
    public let stopReason: String?
    public let text: String
    public let type = "advisor_result"

    public init(text: String, stopReason: String? = nil) {
        self.text = text
        self.stopReason = stopReason
    }

    private enum CodingKeys: String, CodingKey {
        case stopReason, text, type
    }
}
