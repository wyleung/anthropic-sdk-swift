/// Mirrors `types/beta/beta_managed_agents_vault.py`.
public struct BetaManagedAgentsVault: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let createdAt: String
    public let displayName: String
    public let metadata: [String: String]
    public let type: String
    public let updatedAt: String

    public init(
        id: String,
        archivedAt: String? = nil,
        createdAt: String,
        displayName: String,
        metadata: [String: String],
        type: String = "vault",
        updatedAt: String
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.displayName = displayName
        self.metadata = metadata
        self.type = type
        self.updatedAt = updatedAt
    }
}

/// Mirrors `types/beta/beta_managed_agents_deleted_vault.py`, returned by `BetaVaults.delete`.
public struct BetaManagedAgentsDeletedVault: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "vault_deleted") {
        self.id = id
        self.type = type
    }
}
