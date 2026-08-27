import Anthropic

/// Mirrors `types/beta/beta_webhook_session_thread_created_event_data.py`. Unlike the base
/// session-lifecycle/status shape, thread events carry an extra `sessionThreadId` identifying the
/// specific thread within the session.
public struct BetaWebhookSessionThreadCreatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let sessionThreadId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, sessionThreadId: String,
        type: String = "session.thread_created", workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.sessionThreadId = sessionThreadId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_thread_idled_event_data.py`.
public struct BetaWebhookSessionThreadIdledEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let sessionThreadId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, sessionThreadId: String,
        type: String = "session.thread_idled", workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.sessionThreadId = sessionThreadId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_thread_terminated_event_data.py`.
public struct BetaWebhookSessionThreadTerminatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let sessionThreadId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, sessionThreadId: String,
        type: String = "session.thread_terminated", workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.sessionThreadId = sessionThreadId
        self.type = type
        self.workspaceId = workspaceId
    }
}
