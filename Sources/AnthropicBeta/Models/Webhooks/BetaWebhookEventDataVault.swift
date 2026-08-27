import Anthropic

/// Mirrors `types/beta/beta_webhook_vault_created_event_data.py`.
public struct BetaWebhookVaultCreatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "vault.created", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_vault_archived_event_data.py`.
public struct BetaWebhookVaultArchivedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "vault.archived", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_vault_deleted_event_data.py`.
public struct BetaWebhookVaultDeletedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(id: String, organizationId: String, type: String = "vault.deleted", workspaceId: String) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}
