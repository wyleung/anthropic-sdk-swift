import Anthropic

/// Ported from `types/beta/message_create_params.py`. Reuses GA's `CacheControlEphemeral`,
/// `MessageCreateParamsContainerParam`, `MetadataParam`, `ThinkingConfigParam`, `ToolChoiceParam`,
/// `ServiceTier`, and `SystemPromptParam` directly -- all confirmed field-identical to their Beta
/// counterparts. `contextManagement`, `diagnostics`, `fallbackCreditToken`, and `fallbacks` are kept
/// as raw `JSONValue` passthroughs rather than fully typed (each is a deeply-nested union in the
/// Python source). `mcpServers` is omitted entirely for this slice.
public struct BetaMessageCreateParams: Encodable, Sendable, Equatable {
    public let model: String
    public let maxTokens: Int
    public let messages: [BetaMessageParam]
    public let cacheControl: CacheControlEphemeral?
    public let container: MessageCreateParamsContainerParam?
    public let contextManagement: JSONValue?
    public let diagnostics: JSONValue?
    public let fallbackCreditToken: String?
    public let fallbacks: JSONValue?
    public let inferenceGeo: String?
    public let metadata: MetadataParam?
    public let outputConfig: BetaOutputConfigParam?
    public let serviceTier: ServiceTier?
    public let speed: BetaSpeed?
    public let stopSequences: [String]?
    public let system: SystemPromptParam?
    public let thinking: ThinkingConfigParam?
    public let toolChoice: ToolChoiceParam?
    public let tools: [BetaToolUnionParam]?

    public init(
        model: String,
        maxTokens: Int,
        messages: [BetaMessageParam],
        cacheControl: CacheControlEphemeral? = nil,
        container: MessageCreateParamsContainerParam? = nil,
        contextManagement: JSONValue? = nil,
        diagnostics: JSONValue? = nil,
        fallbackCreditToken: String? = nil,
        fallbacks: JSONValue? = nil,
        inferenceGeo: String? = nil,
        metadata: MetadataParam? = nil,
        outputConfig: BetaOutputConfigParam? = nil,
        serviceTier: ServiceTier? = nil,
        speed: BetaSpeed? = nil,
        stopSequences: [String]? = nil,
        system: SystemPromptParam? = nil,
        thinking: ThinkingConfigParam? = nil,
        toolChoice: ToolChoiceParam? = nil,
        tools: [BetaToolUnionParam]? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.cacheControl = cacheControl
        self.container = container
        self.contextManagement = contextManagement
        self.diagnostics = diagnostics
        self.fallbackCreditToken = fallbackCreditToken
        self.fallbacks = fallbacks
        self.inferenceGeo = inferenceGeo
        self.metadata = metadata
        self.outputConfig = outputConfig
        self.serviceTier = serviceTier
        self.speed = speed
        self.stopSequences = stopSequences
        self.system = system
        self.thinking = thinking
        self.toolChoice = toolChoice
        self.tools = tools
    }
}
