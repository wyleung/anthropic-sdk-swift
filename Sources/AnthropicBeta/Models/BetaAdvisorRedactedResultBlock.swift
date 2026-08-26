/// Ported from `types/beta/beta_advisor_redacted_result_block.py`. `encryptedContent` must be
/// round-tripped verbatim, not inspected or modified.
public struct BetaAdvisorRedactedResultBlock: Codable, Sendable, Equatable {
    public let encryptedContent: String
    public let stopReason: String?
    public let type = "advisor_redacted_result"

    public init(encryptedContent: String, stopReason: String? = nil) {
        self.encryptedContent = encryptedContent
        self.stopReason = stopReason
    }

    private enum CodingKeys: String, CodingKey {
        case encryptedContent, stopReason, type
    }
}
