import Anthropic

/// Ported from `types/beta/beta_advisor_tool_result_block_param.py`. Only `cacheControl` is
/// param-exclusive; `content`'s shape is shared with the response side via
/// `BetaAdvisorToolResultContent`.
public struct BetaAdvisorToolResultBlockParam: Encodable, Sendable, Equatable {
    public let content: BetaAdvisorToolResultContent
    public let toolUseId: String
    public let type = "advisor_tool_result"
    public let cacheControl: CacheControlEphemeral?

    public init(content: BetaAdvisorToolResultContent, toolUseId: String, cacheControl: CacheControlEphemeral? = nil) {
        self.content = content
        self.toolUseId = toolUseId
        self.cacheControl = cacheControl
    }
}
