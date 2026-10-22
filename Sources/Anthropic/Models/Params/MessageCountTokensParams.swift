/// Parameters for `messages.countTokens`: the subset of `MessageCreateParams` that affects how many
/// input tokens a request uses (no `maxTokens`, `stopSequences`, `metadata`, ...). Ported from
/// `types/message_count_tokens_params.py`.
///
/// `tools` reuses `ToolUnionParam`: Python's `MessageCountTokensToolParam` is the same 21-member union
/// as `ToolUnionParam`. `userProfileId` and `workspaceId` are headers, not body fields -- pass them to
/// `countTokens(_:userProfileId:options:)` and `RequestOptions(workspaceId:)` respectively.
public struct MessageCountTokensParams: Encodable, Sendable, Equatable {
    public let model: String
    public let messages: [MessageParam]
    public let cacheControl: CacheControlEphemeral?
    public let outputConfig: OutputConfigParam?
    public let speed: Speed?
    public let system: SystemPromptParam?
    public let thinking: ThinkingConfigParam?
    public let toolChoice: ToolChoiceParam?
    public let tools: [ToolUnionParam]?

    public init(
        model: String,
        messages: [MessageParam],
        cacheControl: CacheControlEphemeral? = nil,
        outputConfig: OutputConfigParam? = nil,
        speed: Speed? = nil,
        system: SystemPromptParam? = nil,
        thinking: ThinkingConfigParam? = nil,
        toolChoice: ToolChoiceParam? = nil,
        tools: [ToolUnionParam]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.cacheControl = cacheControl
        self.outputConfig = outputConfig
        self.speed = speed
        self.system = system
        self.thinking = thinking
        self.toolChoice = toolChoice
        self.tools = tools
    }
}
