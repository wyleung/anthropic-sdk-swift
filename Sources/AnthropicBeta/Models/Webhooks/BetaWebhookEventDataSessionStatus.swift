import Anthropic

/// Mirrors `types/beta/beta_webhook_session_status_idled_event_data.py`.
public struct BetaWebhookSessionStatusIdledEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.status_idled", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_status_rescheduled_event_data.py`.
public struct BetaWebhookSessionStatusRescheduledEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "session.status_rescheduled", workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_status_run_started_event_data.py`.
public struct BetaWebhookSessionStatusRunStartedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "session.status_run_started", workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_status_terminated_event_data.py`.
public struct BetaWebhookSessionStatusTerminatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "session.status_terminated", workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}
