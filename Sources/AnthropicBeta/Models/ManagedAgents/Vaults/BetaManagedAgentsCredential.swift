/// Ported from `beta_managed_agents_credential.py`. Sensitive fields (secrets/tokens) are never
/// returned in responses -- see `BetaManagedAgentsCredentialAuth`.
public struct BetaManagedAgentsCredential: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let auth: BetaManagedAgentsCredentialAuth
    public let createdAt: String
    public let metadata: [String: String]
    public let type: String
    public let updatedAt: String
    public let vaultId: String
    public let displayName: String?

    public init(
        id: String,
        archivedAt: String? = nil,
        auth: BetaManagedAgentsCredentialAuth,
        createdAt: String,
        metadata: [String: String],
        type: String = "vault_credential",
        updatedAt: String,
        vaultId: String,
        displayName: String? = nil
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.auth = auth
        self.createdAt = createdAt
        self.metadata = metadata
        self.type = type
        self.updatedAt = updatedAt
        self.vaultId = vaultId
        self.displayName = displayName
    }
}

/// Ported from `beta_managed_agents_deleted_credential.py`, returned by
/// `BetaVaultCredentials.delete`.
public struct BetaManagedAgentsDeletedCredential: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "vault_credential_deleted") {
        self.id = id
        self.type = type
    }
}
