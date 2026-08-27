import Anthropic

/// Mirrors `types/beta/beta_webhook_environment_created_event_data.py`.
public struct BetaWebhookEnvironmentCreatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "environment.created", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_environment_updated_event_data.py`.
public struct BetaWebhookEnvironmentUpdatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "environment.updated", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_environment_archived_event_data.py`.
public struct BetaWebhookEnvironmentArchivedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "environment.archived", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_environment_deleted_event_data.py`.
public struct BetaWebhookEnvironmentDeletedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "environment.deleted", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}
