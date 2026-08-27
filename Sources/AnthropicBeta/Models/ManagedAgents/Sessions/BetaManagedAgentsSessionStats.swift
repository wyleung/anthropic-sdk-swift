import Anthropic

/// Timing statistics for a `session`. Ported from `beta_managed_agents_session_stats.py`.
/// `activeSeconds` excludes idle time; `durationSeconds` is elapsed time since creation, frozen at
/// the final update once the session terminates.
public struct BetaManagedAgentsSessionStats: Codable, Sendable, Equatable {
    public let activeSeconds: Double?
    public let durationSeconds: Double?

    public init(activeSeconds: Double? = nil, durationSeconds: Double? = nil) {
        self.activeSeconds = activeSeconds
        self.durationSeconds = durationSeconds
    }
}
