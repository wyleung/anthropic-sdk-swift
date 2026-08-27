import Anthropic

/// `session.*` session event leaf types. Ported from
/// `types/beta/sessions/beta_managed_agents_session_*.py` and the root-level
/// `types/beta/beta_managed_agents_session_updated_event.py` /
/// `beta_managed_agents_session_usage_event.py` (root path is a Python-generator artifact with no
/// bearing on Swift's file organization).

/// A recoverable or terminal error occurred during session execution. Ported from
/// `beta_managed_agents_session_error_event.py`.
public struct BetaManagedAgentsSessionErrorEvent: Codable, Sendable, Equatable {
    public let error: BetaManagedAgentsSessionEventError
    public let id: String
    public let processedAt: String
    public let type: String

    public init(
        error: BetaManagedAgentsSessionEventError, id: String, processedAt: String,
        type: String = "session.error"
    ) {
        self.error = error
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// The session was rescheduled onto new compute (e.g. after a host became unavailable). Ported
/// from `beta_managed_agents_session_status_rescheduled_event.py`.
public struct BetaManagedAgentsSessionStatusRescheduledEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "session.status_rescheduled") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// The session transitioned to `running`. Ported from
/// `beta_managed_agents_session_status_running_event.py`.
public struct BetaManagedAgentsSessionStatusRunningEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "session.status_running") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// The session transitioned to `idle`, either because the turn ended naturally or because it is
/// blocked on user input. Ported from `beta_managed_agents_session_status_idle_event.py`.
public struct BetaManagedAgentsSessionStatusIdleEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let stopReason: BetaManagedAgentsSessionStopReason
    public let type: String

    public init(
        id: String, processedAt: String, stopReason: BetaManagedAgentsSessionStopReason,
        type: String = "session.status_idle"
    ) {
        self.id = id
        self.processedAt = processedAt
        self.stopReason = stopReason
        self.type = type
    }
}

/// The session was terminated and will no longer process events. Ported from
/// `beta_managed_agents_session_status_terminated_event.py`.
public struct BetaManagedAgentsSessionStatusTerminatedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "session.status_terminated") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// A new session thread (the primary thread, or a sub-agent thread) was created. Ported from
/// `beta_managed_agents_session_thread_created_event.py`.
public struct BetaManagedAgentsSessionThreadCreatedEvent: Codable, Sendable, Equatable {
    public let agentName: String
    public let id: String
    public let processedAt: String
    public let sessionThreadId: String
    public let type: String

    public init(
        agentName: String, id: String, processedAt: String, sessionThreadId: String,
        type: String = "session.thread_created"
    ) {
        self.agentName = agentName
        self.id = id
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
        self.type = type
    }
}

/// The session was deleted. Ported from `beta_managed_agents_session_deleted_event.py`.
public struct BetaManagedAgentsSessionDeletedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "session.deleted") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// A session thread transitioned to `running`. Ported from
/// `beta_managed_agents_session_thread_status_running_event.py`.
public struct BetaManagedAgentsSessionThreadStatusRunningEvent: Codable, Sendable, Equatable {
    public let agentName: String
    public let id: String
    public let processedAt: String
    public let sessionThreadId: String
    public let type: String

    public init(
        agentName: String, id: String, processedAt: String, sessionThreadId: String,
        type: String = "session.thread_status_running"
    ) {
        self.agentName = agentName
        self.id = id
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
        self.type = type
    }
}

/// A session thread transitioned to `idle`. Ported from
/// `beta_managed_agents_session_thread_status_idle_event.py`.
public struct BetaManagedAgentsSessionThreadStatusIdleEvent: Codable, Sendable, Equatable {
    public let agentName: String
    public let id: String
    public let processedAt: String
    public let sessionThreadId: String
    public let stopReason: BetaManagedAgentsSessionStopReason
    public let type: String

    public init(
        agentName: String, id: String, processedAt: String, sessionThreadId: String,
        stopReason: BetaManagedAgentsSessionStopReason, type: String = "session.thread_status_idle"
    ) {
        self.agentName = agentName
        self.id = id
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
        self.stopReason = stopReason
        self.type = type
    }
}

/// A session thread was terminated. Ported from
/// `beta_managed_agents_session_thread_status_terminated_event.py`.
public struct BetaManagedAgentsSessionThreadStatusTerminatedEvent: Codable, Sendable, Equatable {
    public let agentName: String
    public let id: String
    public let processedAt: String
    public let sessionThreadId: String
    public let type: String

    public init(
        agentName: String, id: String, processedAt: String, sessionThreadId: String,
        type: String = "session.thread_status_terminated"
    ) {
        self.agentName = agentName
        self.id = id
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
        self.type = type
    }
}

/// A session thread was rescheduled onto new compute. Ported from
/// `beta_managed_agents_session_thread_status_rescheduled_event.py`.
public struct BetaManagedAgentsSessionThreadStatusRescheduledEvent: Codable, Sendable, Equatable {
    public let agentName: String
    public let id: String
    public let processedAt: String
    public let sessionThreadId: String
    public let type: String

    public init(
        agentName: String, id: String, processedAt: String, sessionThreadId: String,
        type: String = "session.thread_status_rescheduled"
    ) {
        self.agentName = agentName
        self.id = id
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
        self.type = type
    }
}

/// The session's configuration (agent, budget, title, or metadata) was updated. Ported from
/// `types/beta/beta_managed_agents_session_updated_event.py` (root path).
public struct BetaManagedAgentsSessionUpdatedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String
    public let agent: BetaManagedAgentsSessionAgent?
    public let budget: BetaManagedAgentsBudgetLimit?
    public let metadata: [String: String]?
    public let title: String?

    public init(
        id: String, processedAt: String, type: String = "session.updated",
        agent: BetaManagedAgentsSessionAgent? = nil, budget: BetaManagedAgentsBudgetLimit? = nil,
        metadata: [String: String]? = nil, title: String? = nil
    ) {
        self.id = id
        self.processedAt = processedAt
        self.type = type
        self.agent = agent
        self.budget = budget
        self.metadata = metadata
        self.title = title
    }
}

/// A snapshot of the session's cumulative token usage and cost, emitted periodically. Ported from
/// `types/beta/beta_managed_agents_session_usage_event.py` (root path). Reuses the existing
/// `BetaManagedAgentsSessionUsage` type, which is field-identical to Python's
/// `BetaManagedAgentsSessionUsageSnapshot`.
public struct BetaManagedAgentsSessionUsageEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String
    public let usage: BetaManagedAgentsSessionUsage
    public let budget: BetaManagedAgentsBudgetLimit?

    public init(
        id: String, processedAt: String, type: String = "session.usage",
        usage: BetaManagedAgentsSessionUsage, budget: BetaManagedAgentsBudgetLimit? = nil
    ) {
        self.id = id
        self.processedAt = processedAt
        self.type = type
        self.usage = usage
        self.budget = budget
    }
}
