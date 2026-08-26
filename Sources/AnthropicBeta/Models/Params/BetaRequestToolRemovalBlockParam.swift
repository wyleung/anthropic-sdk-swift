import Anthropic

/// Ported from `types/beta/beta_request_tool_removal_block_param.py`. Mid-conversation directive to
/// withdraw a tool from the model's offered set from this point onward.
public struct BetaRequestToolRemovalBlockParam: Encodable, Sendable, Equatable {
    public let tool: BetaToolChangeReferenceParam
    public let type = "tool_removal"
    public let cacheControl: CacheControlEphemeral?

    public init(tool: BetaToolChangeReferenceParam, cacheControl: CacheControlEphemeral? = nil) {
        self.tool = tool
        self.cacheControl = cacheControl
    }
}
