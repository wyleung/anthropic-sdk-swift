import Anthropic

/// Ported from `types/beta/beta_content_block_param.py`'s 24-member union. Wraps GA's entire
/// 16-case `ContentBlockParam` union via `.standard` for every member confirmed field-identical to
/// its GA counterpart (e.g. `beta_request_document_block_param.py` vs. `document_block_param.py`).
/// The 7 genuinely Beta-exclusive kinds (no GA equivalent at all) get dedicated cases. The union's
/// 24th, trailing member is a bare `BetaContentBlock` reference (a "pass through any response-shaped
/// block verbatim" escape valve); since this type is `Encodable`-only, that's already covered by
/// `.raw` with no loss of correctness, so it gets no dedicated case.
public enum BetaContentBlockParam: Sendable, Equatable {
    case standard(ContentBlockParam)
    case advisorToolResult(BetaAdvisorToolResultBlockParam)
    case mcpToolUse(BetaMCPToolUseBlockParam)
    case mcpToolResult(BetaRequestMCPToolResultBlockParam)
    case compaction(BetaCompactionBlockParam)
    case toolAddition(BetaRequestToolAdditionBlockParam)
    case toolRemoval(BetaRequestToolRemovalBlockParam)
    case fallback(BetaFallbackBlockParam)
    case raw(JSONValue)
}

extension BetaContentBlockParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .standard(let value): try value.encode(to: encoder)
        case .advisorToolResult(let value): try value.encode(to: encoder)
        case .mcpToolUse(let value): try value.encode(to: encoder)
        case .mcpToolResult(let value): try value.encode(to: encoder)
        case .compaction(let value): try value.encode(to: encoder)
        case .toolAddition(let value): try value.encode(to: encoder)
        case .toolRemoval(let value): try value.encode(to: encoder)
        case .fallback(let value): try value.encode(to: encoder)
        case .raw(let value): try value.encode(to: encoder)
        }
    }
}
