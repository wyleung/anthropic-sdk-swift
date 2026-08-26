public enum ServiceTier: String, Encodable, Sendable, Equatable {
    case auto
    case standardOnly = "standard_only"
}

public struct MessageCreateParams: Encodable, Sendable, Equatable {
    public let model: String
    public let maxTokens: Int
    public let messages: [MessageParam]
    public let cacheControl: CacheControlEphemeral?
    public let container: MessageCreateParamsContainerParam?
    public let inferenceGeo: String?
    public let metadata: MetadataParam?
    public let outputConfig: OutputConfigParam?
    public let serviceTier: ServiceTier?
    public let stopSequences: [String]?
    public let system: SystemPromptParam?
    public let thinking: ThinkingConfigParam?
    public let toolChoice: ToolChoiceParam?
    public let tools: [ToolUnionParam]?

    public init(
        model: String,
        maxTokens: Int,
        messages: [MessageParam],
        cacheControl: CacheControlEphemeral? = nil,
        container: MessageCreateParamsContainerParam? = nil,
        inferenceGeo: String? = nil,
        metadata: MetadataParam? = nil,
        outputConfig: OutputConfigParam? = nil,
        serviceTier: ServiceTier? = nil,
        stopSequences: [String]? = nil,
        system: SystemPromptParam? = nil,
        thinking: ThinkingConfigParam? = nil,
        toolChoice: ToolChoiceParam? = nil,
        tools: [ToolUnionParam]? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.cacheControl = cacheControl
        self.container = container
        self.inferenceGeo = inferenceGeo
        self.metadata = metadata
        self.outputConfig = outputConfig
        self.serviceTier = serviceTier
        self.stopSequences = stopSequences
        self.system = system
        self.thinking = thinking
        self.toolChoice = toolChoice
        self.tools = tools
    }
}
