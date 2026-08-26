import Anthropic

/// Ported from `types/beta/beta_request_mcp_tool_result_block_param.py`. Unlike the response side,
/// `content` and `isError` are both optional here (Python's `total=False` TypedDict marks only
/// `tool_use_id`/`type` as `Required`).
public struct BetaRequestMCPToolResultBlockParam: Encodable, Sendable, Equatable {
    public enum Content: Sendable, Equatable {
        case text(String)
        case blocks([TextBlockParam])
    }

    public let toolUseId: String
    public let type = "mcp_tool_result"
    public let cacheControl: CacheControlEphemeral?
    public let content: Content?
    public let isError: Bool?

    public init(
        toolUseId: String, content: Content? = nil, isError: Bool? = nil,
        cacheControl: CacheControlEphemeral? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
        self.cacheControl = cacheControl
    }
}

extension BetaRequestMCPToolResultBlockParam.Content: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .blocks(let value): try container.encode(value)
        }
    }
}
