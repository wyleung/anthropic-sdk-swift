/// Ported from `types/capability_support.py`.
public struct CapabilitySupport: Codable, Sendable, Equatable {
    public let supported: Bool
}

/// Ported from `types/thinking_types.py`.
///
/// `betweenTools` and `disabled` were added after this port; optional so a payload without them
/// still decodes.
public struct ThinkingTypes: Codable, Sendable, Equatable {
    public let adaptive: CapabilitySupport
    public let betweenTools: CapabilitySupport?
    public let disabled: CapabilitySupport?
    public let enabled: CapabilitySupport
}

/// Ported from `types/thinking_capability.py`.
public struct ThinkingCapability: Codable, Sendable, Equatable {
    public let supported: Bool
    public let types: ThinkingTypes
}

/// Ported from `types/effort_capability.py`.
public struct EffortCapability: Codable, Sendable, Equatable {
    public let high: CapabilitySupport
    public let low: CapabilitySupport
    public let max: CapabilitySupport
    public let medium: CapabilitySupport
    public let supported: Bool
    public let xhigh: CapabilitySupport?
}

/// Ported from `types/context_management_capability.py`.
public struct ContextManagementCapability: Codable, Sendable, Equatable {
    public let clearThinking20251015: CapabilitySupport?
    public let clearToolUses20250919: CapabilitySupport?
    public let compact20260112: CapabilitySupport?
    public let supported: Bool
}

/// Web search and code execution tool support, with one entry per tool. Ported from
/// `types/server_tools_capability.py`.
public struct ServerToolsCapability: Codable, Sendable, Equatable {
    public let codeExecution: CapabilitySupport
    public let supported: Bool
    public let webSearch: CapabilitySupport
}

/// Ported from `types/model_capabilities.py`.
public struct ModelCapabilities: Codable, Sendable, Equatable {
    public let batch: CapabilitySupport
    public let citations: CapabilitySupport
    public let codeExecution: CapabilitySupport
    public let contextManagement: ContextManagementCapability
    public let effort: EffortCapability
    public let imageInput: CapabilitySupport
    public let pdfInput: CapabilitySupport
    /// Optional because it postdates this port; see `ThinkingTypes`.
    public let serverTools: ServerToolsCapability?
    public let structuredOutputs: CapabilitySupport
    public let thinking: ThinkingCapability
}
