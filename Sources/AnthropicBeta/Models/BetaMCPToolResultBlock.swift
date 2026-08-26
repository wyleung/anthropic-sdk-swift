import Anthropic

/// Ported from `types/beta/beta_mcp_tool_result_block.py`. `content` is `Union[str, List[BetaTextBlock]]`
/// -- `BetaTextBlock` is field-identical to GA's `TextBlock`, so it's reused directly. Unlike
/// `BetaMCPToolUseBlock`, there is no `server_name` field here (confirmed in the Python source).
public struct BetaMCPToolResultBlock: Codable, Sendable, Equatable {
    public enum Content: Sendable, Equatable {
        case text(String)
        case blocks([TextBlock])
    }

    public let content: Content
    public let isError: Bool
    public let toolUseId: String
    public let type = "mcp_tool_result"

    public init(content: Content, isError: Bool, toolUseId: String) {
        self.content = content
        self.isError = isError
        self.toolUseId = toolUseId
    }

    private enum CodingKeys: String, CodingKey {
        case content, isError, toolUseId, type
    }
}

extension BetaMCPToolResultBlock.Content: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .blocks(try container.decode([TextBlock].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .blocks(let value): try container.encode(value)
        }
    }
}
