import Anthropic

/// Timing statistics for a `session_thread`. Ported from
/// `sessions/beta_managed_agents_session_thread_stats.py`. Unlike session-level
/// `BetaManagedAgentsSessionStats`, this carries an extra `startupSeconds` (zero for child threads,
/// which start immediately).
public struct BetaManagedAgentsSessionThreadStats: Codable, Sendable, Equatable {
    public let activeSeconds: Double?
    public let durationSeconds: Double?
    public let startupSeconds: Double?

    public init(activeSeconds: Double? = nil, durationSeconds: Double? = nil, startupSeconds: Double? = nil) {
        self.activeSeconds = activeSeconds
        self.durationSeconds = durationSeconds
        self.startupSeconds = startupSeconds
    }
}

/// Cumulative token usage for a `session_thread` across all turns. Ported from
/// `sessions/beta_managed_agents_session_thread_usage.py`. Same field shape as
/// `BetaManagedAgentsSessionUsage` and shares its `cacheCreation`/`serverToolUse` leaf types, but
/// kept as a distinct type mirroring Python's own separate nominal type. `activeSeconds` here
/// equals `stats.activeSeconds` for *this thread only* -- contrast with session-level
/// `BetaManagedAgentsSessionUsage.activeSeconds`, which collapses concurrent-thread overlap across
/// the whole session.
public struct BetaManagedAgentsSessionThreadUsage: Codable, Sendable, Equatable {
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

/// An execution thread within a `session`: one primary thread plus zero or more child threads
/// spawned by the coordinator. Ported from `sessions/beta_managed_agents_session_thread.py`.
/// `agent` reuses `BetaManagedAgentsCoordinatorAgent` (the `SessionThreadAgent`/`Advisor` union
/// declared locally as `Agent` in both this file and
/// `beta_managed_agents_session_multiagent_coordinator.py`), and `status` reuses the shared
/// `BetaManagedAgentsSessionStatus` enum -- see that type's doc comment for why the session-level
/// and thread-level Python status aliases were collapsed into one.
public struct BetaManagedAgentsSessionThread: Codable, Sendable, Equatable {
    public let id: String
    public let agent: BetaManagedAgentsCoordinatorAgent
    public let archivedAt: String?
    public let createdAt: String
    public let parentThreadId: String?
    public let sessionId: String
    public let stats: BetaManagedAgentsSessionThreadStats?
    public let status: BetaManagedAgentsSessionStatus
    public let type: String
    public let updatedAt: String
    public let usage: BetaManagedAgentsSessionThreadUsage?

    public init(
        id: String,
        agent: BetaManagedAgentsCoordinatorAgent,
        archivedAt: String? = nil,
        createdAt: String,
        parentThreadId: String? = nil,
        sessionId: String,
        stats: BetaManagedAgentsSessionThreadStats? = nil,
        status: BetaManagedAgentsSessionStatus,
        type: String = "session_thread",
        updatedAt: String,
        usage: BetaManagedAgentsSessionThreadUsage? = nil
    ) {
        self.id = id
        self.agent = agent
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.parentThreadId = parentThreadId
        self.sessionId = sessionId
        self.stats = stats
        self.status = status
        self.type = type
        self.updatedAt = updatedAt
        self.usage = usage
    }
}
