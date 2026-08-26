import Anthropic

/// Ported from `types/beta/beta_request_tool_addition_block_param.py`. Mid-conversation directive to
/// surface a previously-declared tool to the model from this point onward.
public struct BetaRequestToolAdditionBlockParam: Encodable, Sendable, Equatable {
    public let tool: BetaToolChangeReferenceParam
    public let type = "tool_addition"
    public let cacheControl: CacheControlEphemeral?

    public init(tool: BetaToolChangeReferenceParam, cacheControl: CacheControlEphemeral? = nil) {
        self.tool = tool
        self.cacheControl = cacheControl
    }
}
