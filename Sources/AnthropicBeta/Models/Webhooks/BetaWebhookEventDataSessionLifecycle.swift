import Anthropic

/// Mirrors `types/beta/beta_webhook_session_created_event_data.py`.
public struct BetaWebhookSessionCreatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.created", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_pending_event_data.py`.
public struct BetaWebhookSessionPendingEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.pending", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_running_event_data.py`.
public struct BetaWebhookSessionRunningEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.running", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_idled_event_data.py`.
public struct BetaWebhookSessionIdledEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.idled", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_requires_action_event_data.py`.
public struct BetaWebhookSessionRequiresActionEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.requires_action", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_archived_event_data.py`.
public struct BetaWebhookSessionArchivedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.archived", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_deleted_event_data.py`.
public struct BetaWebhookSessionDeletedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.deleted", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_updated_event_data.py`.
public struct BetaWebhookSessionUpdatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.updated", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_session_budget_reached_event_data.py`.
public struct BetaWebhookSessionBudgetReachedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "session.budget_reached", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}
