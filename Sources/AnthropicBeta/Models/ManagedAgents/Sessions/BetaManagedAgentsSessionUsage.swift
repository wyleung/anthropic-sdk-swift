import Anthropic

/// Cumulative count of server-executed tool invocations, broken down by tool. Ported from
/// `beta_managed_agents_server_tool_usage.py`. Shared verbatim by `BetaManagedAgentsSessionUsage`
/// and `BetaManagedAgentsSessionThreadUsage`, matching Python's own reuse. **Not** the same shape
/// as GA's `ServerToolUsage` -- these fields are `Int?` here, `Int` (non-optional) on GA's type.
public struct BetaManagedAgentsServerToolUsage: Codable, Sendable, Equatable {
    public let webFetchRequests: Int?
    public let webSearchRequests: Int?

    public init(webFetchRequests: Int? = nil, webSearchRequests: Int? = nil) {
        self.webFetchRequests = webFetchRequests
        self.webSearchRequests = webSearchRequests
    }
}

/// Prompt-cache creation token usage broken down by cache lifetime. Ported from
/// `beta_managed_agents_cache_creation_usage.py`. Shared verbatim by
/// `BetaManagedAgentsSessionUsage` and `BetaManagedAgentsSessionThreadUsage`. **Not** the same
/// shape as GA's `CacheCreation` -- these fields are `Int?` here, `Int` (non-optional) on GA's
/// type.
public struct BetaManagedAgentsCacheCreationUsage: Codable, Sendable, Equatable {
    /// Capital `H`/`M` (not `ephemeral1hInputTokens`/`ephemeral5mInputTokens`) is deliberate:
    /// Foundation's `.convertFromSnakeCase` maps the wire's `ephemeral_1h_input_tokens` /
    /// `ephemeral_5m_input_tokens` to `ephemeral1HInputTokens` / `ephemeral5MInputTokens`,
    /// uppercasing the letter immediately after a digit run rather than the first character of the
    /// `1h`/`5m` segment. See `CacheCreation` (GA) for the same fix.
    public let ephemeral1HInputTokens: Int?
    public let ephemeral5MInputTokens: Int?

    public init(ephemeral1HInputTokens: Int? = nil, ephemeral5MInputTokens: Int? = nil) {
        self.ephemeral1HInputTokens = ephemeral1HInputTokens
        self.ephemeral5MInputTokens = ephemeral5MInputTokens
    }
}

/// Cumulative token usage for a `session` across all turns. Ported from
/// `beta_managed_agents_session_usage.py`. `activeSeconds` counts time with *at least one thread*
/// running, collapsing concurrent-thread overlap -- contrast with
/// `BetaManagedAgentsSessionThreadUsage.activeSeconds`, which is scoped to a single thread's own
/// running time.
public struct BetaManagedAgentsSessionUsage: Codable, Sendable, Equatable {
    public let activeSeconds: Double?
    public let cacheCreation: BetaManagedAgentsCacheCreationUsage?
    public let cacheReadInputTokens: Int?
    public let inputTokens: Int?
    public let listCost: BetaMonetaryAmount?
    public let outputTokens: Int?
    public let serverToolUse: BetaManagedAgentsServerToolUsage?

    public init(
        activeSeconds: Double? = nil,
        cacheCreation: BetaManagedAgentsCacheCreationUsage? = nil,
        cacheReadInputTokens: Int? = nil,
        inputTokens: Int? = nil,
        listCost: BetaMonetaryAmount? = nil,
        outputTokens: Int? = nil,
        serverToolUse: BetaManagedAgentsServerToolUsage? = nil
    ) {
        self.activeSeconds = activeSeconds
        self.cacheCreation = cacheCreation
        self.cacheReadInputTokens = cacheReadInputTokens
        self.inputTokens = inputTokens
        self.listCost = listCost
        self.outputTokens = outputTokens
        self.serverToolUse = serverToolUse
    }
}
