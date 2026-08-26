import Anthropic

/// Wraps GA's entire 21-case `ToolUnionParam` union via `.tool` rather than duplicating every tool
/// param type. `.raw` is the escape hatch for Beta-exclusive tool kinds this slice doesn't model
/// (e.g. the memory tool's Beta-only variants, tool-search kinds beyond GA parity).
public enum BetaToolUnionParam: Sendable, Equatable {
    case tool(ToolUnionParam)
    case raw(JSONValue)
}

extension BetaToolUnionParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tool(let value): try value.encode(to: encoder)
        case .raw(let value): try value.encode(to: encoder)
        }
    }
}
