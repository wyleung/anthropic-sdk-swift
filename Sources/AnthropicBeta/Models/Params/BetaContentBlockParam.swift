import Anthropic

/// Wraps GA's entire 16-case `ContentBlockParam` union via `.standard` -- every Beta request block
/// param confirmed field-identical to its GA counterpart (e.g. `beta_request_document_block_param.py`
/// vs. `document_block_param.py`) decodes/encodes fine as the GA type. `.raw` is the escape hatch
/// for the genuinely Beta-exclusive param cases this slice doesn't model as dedicated types (MCP
/// tool use/result, compaction, fallback, tool add/remove, advisor tool result).
public enum BetaContentBlockParam: Sendable, Equatable {
    case standard(ContentBlockParam)
    case raw(JSONValue)
}

extension BetaContentBlockParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .standard(let value): try value.encode(to: encoder)
        case .raw(let value): try value.encode(to: encoder)
        }
    }
}
