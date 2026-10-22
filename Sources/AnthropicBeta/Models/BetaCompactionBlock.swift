/// Ported from `types/beta/beta_compaction_block.py`. Returned when autocompact triggers; `content
/// == nil` means compaction failed to produce a valid summary (server treats it as a no-op on
/// round-trip), not that there's nothing to summarize.
///
/// `signature` and `toolChanges` must be sent back with the block verbatim -- `asRequestParam()` does.
/// `toolChanges` is the `tool_addition`/`tool_removal` blocks that take the request's `tools` to the
/// tool set in effect at the end of the compacted range: `[]` when the range changed no tool, `nil` when
/// the server didn't compute them.
public struct BetaCompactionBlock: Codable, Sendable, Equatable {
    public let content: String?
    public let encryptedContent: String?
    public let signature: String?
    public let toolChanges: [BetaCompactionToolChange]?
    public let type = "compaction"

    public init(
        content: String?,
        encryptedContent: String?,
        signature: String? = nil,
        toolChanges: [BetaCompactionToolChange]? = nil
    ) {
        self.content = content
        self.encryptedContent = encryptedContent
        self.signature = signature
        self.toolChanges = toolChanges
    }

    private enum CodingKeys: String, CodingKey {
        case content, encryptedContent, signature, toolChanges, type
    }
}
