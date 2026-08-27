import Anthropic

/// Mirrors `types/beta/beta_webhook_memory_store_created_event_data.py`.
public struct BetaWebhookMemoryStoreCreatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "memory_store.created", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_memory_store_archived_event_data.py`.
public struct BetaWebhookMemoryStoreArchivedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "memory_store.archived", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_memory_store_deleted_event_data.py`.
public struct BetaWebhookMemoryStoreDeletedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "memory_store.deleted", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}
