/// Ported from `types/beta/environments/beta_self_hosted_work.py`. Work items are queued when
/// sessions are created (or long-dormant sessions receive new messages) in a self-hosted
/// environment; the operator's worker process polls this queue to execute them.
public struct BetaSelfHostedWork: Codable, Sendable, Equatable {
    public let id: String
    public let acknowledgedAt: String?
    public let createdAt: String
    public let data: BetaSessionWorkData
    public let environmentId: String
    public let latestHeartbeatAt: String?
    public let metadata: [String: String]
    /// Credential payload used by the environment worker to execute this work item. May be
    /// populated when polling for work; `nil` on all other retrieval paths.
    public let secret: String?
    public let startedAt: String?
    public let state: BetaWorkState
    public let stopRequestedAt: String?
    public let stoppedAt: String?
    public let type: String

    public init(
        id: String, acknowledgedAt: String? = nil, createdAt: String, data: BetaSessionWorkData,
        environmentId: String, latestHeartbeatAt: String? = nil, metadata: [String: String],
        secret: String? = nil, startedAt: String? = nil, state: BetaWorkState,
        stopRequestedAt: String? = nil, stoppedAt: String? = nil, type: String = "work"
    ) {
        self.id = id
        self.acknowledgedAt = acknowledgedAt
        self.createdAt = createdAt
        self.data = data
        self.environmentId = environmentId
        self.latestHeartbeatAt = latestHeartbeatAt
        self.metadata = metadata
        self.secret = secret
        self.startedAt = startedAt
        self.state = state
        self.stopRequestedAt = stopRequestedAt
        self.stoppedAt = stoppedAt
        self.type = type
    }
}

/// Ported from `types/beta/environments/beta_session_work_data.py`.
public struct BetaSessionWorkData: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "session") {
        self.id = id
        self.type = type
    }
}

/// Ported from the inline `Literal["queued", "starting", "active", "stopping", "stopped"]` shared
/// by `BetaSelfHostedWork.state` and `BetaSelfHostedWorkHeartbeatResponse.state`.
public enum BetaWorkState: Sendable, Equatable {
    case queued
    case starting
    case active
    case stopping
    case stopped
    case unknown(String)
}

extension BetaWorkState: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "queued": self = .queued
        case "starting": self = .starting
        case "active": self = .active
        case "stopping": self = .stopping
        case "stopped": self = .stopped
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .queued: try container.encode("queued")
        case .starting: try container.encode("starting")
        case .active: try container.encode("active")
        case .stopping: try container.encode("stopping")
        case .stopped: try container.encode("stopped")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
