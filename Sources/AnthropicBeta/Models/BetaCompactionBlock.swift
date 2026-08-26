/// Ported from `types/beta/beta_compaction_block.py`. Returned when autocompact triggers; `content
/// == nil` means compaction failed to produce a valid summary (server treats it as a no-op on
/// round-trip), not that there's nothing to summarize.
public struct BetaCompactionBlock: Codable, Sendable, Equatable {
    public let content: String?
    public let encryptedContent: String?
    public let type = "compaction"

    public init(content: String?, encryptedContent: String?) {
        self.content = content
        self.encryptedContent = encryptedContent
    }

    private enum CodingKeys: String, CodingKey {
        case content, encryptedContent, type
    }
}
