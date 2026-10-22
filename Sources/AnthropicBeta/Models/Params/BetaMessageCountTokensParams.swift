import Anthropic

/// Parameters for `beta.messages.countTokens`: the subset of `BetaMessageCreateParams` that affects
/// how many input tokens a request uses. Ported from `types/beta/message_count_tokens_params.py`,
/// with every shared field typed exactly as on `BetaMessageCreateParams`; `tools` reuses
/// `BetaToolUnionParam` (Python's count-tokens `Tool` is the same 28-member union).
///
/// `betas`, `userProfileId` and `workspaceId` are headers, not body fields -- pass them to
/// `countTokens(_:betas:userProfileId:options:)` and `RequestOptions(workspaceId:)`.
///
/// `compaction` is accepted but ignored by the API ("the count it returns is for the conversation in
/// `messages` as sent"); it is here so a request built for `create` can be counted unchanged.
public struct BetaMessageCountTokensParams: Encodable, Sendable, Equatable {
    public let model: String
    public let messages: [BetaMessageParam]
    public let cacheControl: CacheControlEphemeral?
    public let compaction: BetaCompactionConfigParam?
    public let contextManagement: JSONValue?
    public let mcpServers: [BetaRequestMCPServerURLDefinitionParam]?
    public let outputConfig: BetaOutputConfigParam?
    public let speed: BetaSpeed?
    public let system: SystemPromptParam?
    public let thinking: BetaThinkingConfigParam?
    public let toolChoice: ToolChoiceParam?
    public let tools: [BetaToolUnionParam]?

    public init(
        model: String,
        messages: [BetaMessageParam],
        cacheControl: CacheControlEphemeral? = nil,
        compaction: BetaCompactionConfigParam? = nil,
        contextManagement: JSONValue? = nil,
        mcpServers: [BetaRequestMCPServerURLDefinitionParam]? = nil,
        outputConfig: BetaOutputConfigParam? = nil,
        speed: BetaSpeed? = nil,
        system: SystemPromptParam? = nil,
        thinking: BetaThinkingConfigParam? = nil,
        toolChoice: ToolChoiceParam? = nil,
        tools: [BetaToolUnionParam]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.cacheControl = cacheControl
        self.compaction = compaction
        self.contextManagement = contextManagement
        self.mcpServers = mcpServers
        self.outputConfig = outputConfig
        self.speed = speed
        self.system = system
        self.thinking = thinking
        self.toolChoice = toolChoice
        self.tools = tools
    }
}
