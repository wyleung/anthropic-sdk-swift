/// Ported from `types/beta/environments/beta_self_hosted_work_heartbeat_response.py`.
public struct BetaSelfHostedWorkHeartbeatResponse: Codable, Sendable, Equatable {
    public let lastHeartbeat: String
    public let leaseExtended: Bool
    public let state: BetaWorkState
    public let ttlSeconds: Int
    public let type: String
}
