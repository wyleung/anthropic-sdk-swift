/// Ported from `types/beta/environments/beta_self_hosted_work_heartbeat_response.py`.
public struct BetaSelfHostedWorkHeartbeatResponse: Codable, Sendable, Equatable {
    public let lastHeartbeat: String
    public let leaseExtended: Bool
    public let state: BetaWorkState
    public let ttlSeconds: Int
    public let type: String

    public init(
        lastHeartbeat: String, leaseExtended: Bool, state: BetaWorkState, ttlSeconds: Int,
        type: String = "work_heartbeat"
    ) {
        self.lastHeartbeat = lastHeartbeat
        self.leaseExtended = leaseExtended
        self.state = state
        self.ttlSeconds = ttlSeconds
        self.type = type
    }
}
