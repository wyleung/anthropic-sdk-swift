import Anthropic

/// A session went idle because the model refused. Ported from `sessions/beta_managed_agents_session_refusal.py`;
/// the details arrive alongside it on the idle event as `stopDetails`.
public struct BetaManagedAgentsSessionRefusal: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "refusal") {
        self.type = type
    }
}

/// Why the model refused. Ported from `sessions/beta_managed_agents_session_refusal_stop_details.py`;
/// the same shape as GA's `RefusalStopDetails`, whose `RefusalCategory` it reuses.
public struct BetaManagedAgentsSessionRefusalStopDetails: Codable, Sendable, Equatable {
    public let category: RefusalCategory?
    public let explanation: String?
    public let type: String

    public init(category: RefusalCategory? = nil, explanation: String? = nil, type: String = "refusal") {
        self.category = category
        self.explanation = explanation
        self.type = type
    }
}
