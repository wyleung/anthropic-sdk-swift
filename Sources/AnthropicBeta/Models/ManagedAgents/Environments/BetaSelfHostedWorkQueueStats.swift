/// Ported from `types/beta/environments/beta_self_hosted_work_queue_stats.py`. Backed by Redis
/// Stream consumer group metrics, per the Python docstring, for O(1) queries.
public struct BetaSelfHostedWorkQueueStats: Codable, Sendable, Equatable {
    public let depth: Int
    /// `nil` if the work stream is empty.
    public let oldestQueuedAt: String?
    public let pending: Int
    public let type: String
    /// Number of workers that polled for work in the last 30 seconds. Requires `workerId` to be
    /// sent with poll requests.
    public let workersPolling: Int?
}
