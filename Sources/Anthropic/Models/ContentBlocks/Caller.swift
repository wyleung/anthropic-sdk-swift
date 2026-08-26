/// Identifies what invoked a server tool. Ported from `direct_caller.py`/`server_tool_caller.py`/
/// `server_tool_caller_20260120.py`'s discriminated union, shared by `ToolUseBlock`,
/// `ServerToolUseBlock`, `WebSearchToolResultBlock`, and `WebFetchToolResultBlock`.
public enum Caller: Sendable, Equatable {
    case direct
    case codeExecution20250825(toolId: String)
    case codeExecution20260120(toolId: String)
    case unknown(type: String, raw: JSONValue)
}

extension Caller: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case toolId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "direct":
            self = .direct
        case "code_execution_20250825":
            self = .codeExecution20250825(toolId: try container.decode(String.self, forKey: .toolId))
        case "code_execution_20260120":
            self = .codeExecution20260120(toolId: try container.decode(String.self, forKey: .toolId))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .direct:
            try container.encode("direct", forKey: .type)
        case .codeExecution20250825(let toolId):
            try container.encode("code_execution_20250825", forKey: .type)
            try container.encode(toolId, forKey: .toolId)
        case .codeExecution20260120(let toolId):
            try container.encode("code_execution_20260120", forKey: .type)
            try container.encode(toolId, forKey: .toolId)
        case .unknown(_, let raw):
            try raw.encode(to: encoder)
        }
    }
}
