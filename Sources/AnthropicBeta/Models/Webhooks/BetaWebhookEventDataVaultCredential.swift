import Anthropic

/// Mirrors `types/beta/beta_webhook_vault_credential_created_event_data.py`. Unlike the base
/// vault shape, credential events carry an extra `vaultId` identifying the owning vault.
public struct BetaWebhookVaultCredentialCreatedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let vaultId: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "vault_credential.created", vaultId: String,
        workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.vaultId = vaultId
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_vault_credential_archived_event_data.py`.
public struct BetaWebhookVaultCredentialArchivedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let vaultId: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "vault_credential.archived", vaultId: String,
        workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.vaultId = vaultId
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_vault_credential_deleted_event_data.py`.
public struct BetaWebhookVaultCredentialDeletedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let vaultId: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "vault_credential.deleted", vaultId: String,
        workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.vaultId = vaultId
        self.workspaceId = workspaceId
    }
}

/// Mirrors `types/beta/beta_webhook_vault_credential_refresh_failed_event_data.py`.
public struct BetaWebhookVaultCredentialRefreshFailedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let vaultId: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "vault_credential.refresh_failed",
        vaultId: String, workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.vaultId = vaultId
        self.workspaceId = workspaceId
    }
}
