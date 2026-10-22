import Anthropic

/// Whether the model accepts the top-level `compaction` request parameter, with one entry per supported
/// `compaction.type` value. Ported from `types/beta/beta_compaction_capability.py`.
public struct BetaCompactionCapability: Codable, Sendable, Equatable {
    /// Whether the `summarize` compaction type is supported.
    public let summarize: CapabilitySupport
    public let supported: Bool
}

/// Ported from `types/beta/beta_model_capabilities.py`: GA's `ModelCapabilities` plus `compaction`.
/// Every other field reuses GA's leaf types (`CapabilitySupport`, `ThinkingCapability`, ...), which are
/// field-identical to their Beta counterparts. Like GA, the fields that postdate this port --
/// `compaction` and `serverTools` -- are optional so a payload without them still decodes.
public struct BetaModelCapabilities: Codable, Sendable, Equatable {
    public let batch: CapabilitySupport
    public let citations: CapabilitySupport
    public let codeExecution: CapabilitySupport
    public let compaction: BetaCompactionCapability?
    public let contextManagement: ContextManagementCapability
    public let effort: EffortCapability
    public let imageInput: CapabilitySupport
    public let pdfInput: CapabilitySupport
    public let serverTools: ServerToolsCapability?
    public let structuredOutputs: CapabilitySupport
    public let thinking: ThinkingCapability
}
