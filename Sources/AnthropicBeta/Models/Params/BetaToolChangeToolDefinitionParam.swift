import Anthropic

/// A tool added mid-conversation by its full definition (rather than by reference to one already
/// declared in `tools`). Ported from `types/beta/beta_tool_change_tool_definition_param.py`. Requires
/// `anthropic-beta: inline-tools-2026-09-15`.
public struct BetaToolChangeToolDefinitionParam: Encodable, Sendable, Equatable {
    public let type = "tool_definition"
    public let definition: BetaToolUnionParam

    public init(definition: BetaToolUnionParam) {
        self.definition = definition
    }
}

/// The tool a `tool_addition` block surfaces. Ported from `BetaRequestToolAdditionBlockParam.Tool`:
/// the three by-reference forms a `tool_removal` also accepts, plus a full definition -- which is why
/// removal keeps `BetaToolChangeReferenceParam` and addition needs this wider type.
public enum BetaToolAdditionParam: Sendable, Equatable {
    case reference(BetaToolChangeReferenceParam)
    case definition(BetaToolChangeToolDefinitionParam)
}

extension BetaToolAdditionParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .reference(let value): try value.encode(to: encoder)
        case .definition(let value): try value.encode(to: encoder)
        }
    }
}
