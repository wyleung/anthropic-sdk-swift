import Anthropic

/// Ported from `types/beta/beta_compaction_block_param.py`. Callers should round-trip a response
/// `BetaCompactionBlock` back into this shape verbatim across a compaction boundary. Empty-string
/// `content` is documented as disallowed, but that's a server-side validation rule, not something
/// the Swift type system enforces here.
///
/// `signature` and `toolChanges` come from the response block and must be sent back verbatim: the
/// signature authenticates the summary, and `toolChanges` records which tools were added or removed
/// across the summarized range. `nil` means the server didn't send them; an empty `toolChanges` means it
/// computed that nothing changed -- the two are different and are encoded differently.
public struct BetaCompactionBlockParam: Encodable, Sendable, Equatable {
    public let type = "compaction"
    public let cacheControl: CacheControlEphemeral?
    public let content: String?
    public let encryptedContent: String?
    public let signature: String?
    public let toolChanges: [BetaCompactionToolChangeParam]?

    public init(
        content: String? = nil,
        encryptedContent: String? = nil,
        signature: String? = nil,
        toolChanges: [BetaCompactionToolChangeParam]? = nil,
        cacheControl: CacheControlEphemeral? = nil
    ) {
        self.content = content
        self.encryptedContent = encryptedContent
        self.signature = signature
        self.toolChanges = toolChanges
        self.cacheControl = cacheControl
    }
}

/// One entry of `BetaCompactionBlockParam.toolChanges`. Ported from `BetaCompactionBlockParam.ToolChange`.
/// `raw` is what a response block's entries convert to: upstream says to send them back unchanged, and
/// the response and request wire shapes are identical, so the exact JSON is passed through (including
/// entry types newer than this port).
public enum BetaCompactionToolChangeParam: Sendable, Equatable {
    case addition(BetaRequestToolAdditionBlockParam)
    case removal(BetaRequestToolRemovalBlockParam)
    case raw(JSONValue)
}

extension BetaCompactionToolChangeParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .addition(let value): try value.encode(to: encoder)
        case .removal(let value): try value.encode(to: encoder)
        case .raw(let value): try value.encode(to: encoder)
        }
    }
}
