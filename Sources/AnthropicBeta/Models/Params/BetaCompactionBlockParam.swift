import Anthropic

/// Ported from `types/beta/beta_compaction_block_param.py`. Callers should round-trip a response
/// `BetaCompactionBlock` back into this shape verbatim across a compaction boundary. Empty-string
/// `content` is documented as disallowed, but that's a server-side validation rule, not something
/// the Swift type system enforces here.
public struct BetaCompactionBlockParam: Encodable, Sendable, Equatable {
    public let type = "compaction"
    public let cacheControl: CacheControlEphemeral?
    public let content: String?
    public let encryptedContent: String?

    public init(content: String? = nil, encryptedContent: String? = nil, cacheControl: CacheControlEphemeral? = nil) {
        self.content = content
        self.encryptedContent = encryptedContent
        self.cacheControl = cacheControl
    }
}
