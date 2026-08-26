import Anthropic

/// Ported from `types/beta/beta_tool_union_param.py`'s 28-member union. Wraps GA's entire 21-case
/// `ToolUnionParam` union via `.tool` for every member GA already covers exactly (custom tool,
/// bash20250124, code execution x4, browser/computer/memory toolsets, text editor x3, web
/// search/fetch x7, tool search x2). `.mcpToolset` and `.advisor` are the two members with no GA
/// equivalent. `.raw` remains the escape hatch for the 5 legacy-only members this slice deliberately
/// skips (bash20241022 and the standalone computer-use 20241022/20250124/20251124 variants, plus
/// textEditor20241022) -- superseded by GA's newer toolset-based equivalents, out of scope here.
public enum BetaToolUnionParam: Sendable, Equatable {
    case tool(ToolUnionParam)
    case mcpToolset(BetaMCPToolsetParam)
    case advisor(BetaAdvisorTool20260301Param)
    case raw(JSONValue)
}

extension BetaToolUnionParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tool(let value): try value.encode(to: encoder)
        case .mcpToolset(let value): try value.encode(to: encoder)
        case .advisor(let value): try value.encode(to: encoder)
        case .raw(let value): try value.encode(to: encoder)
        }
    }
}
