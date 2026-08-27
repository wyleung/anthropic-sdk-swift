/// A `memory_store`: a named container for agent memories, scoped to a workspace. Attach a store
/// to a session via `resources[]` to mount it as a directory the agent can read and write. Mirrors
/// `types/beta/beta_managed_agents_memory_store.py`.
public struct BetaManagedAgentsMemoryStore: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let createdAt: String
    public let description: String?
    public let metadata: [String: String]?
    public let name: String
    public let type: String
    public let updatedAt: String

    public init(
        id: String,
        archivedAt: String? = nil,
        createdAt: String,
        description: String? = nil,
        metadata: [String: String]? = nil,
        name: String,
        type: String = "memory_store",
        updatedAt: String
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.description = description
        self.metadata = metadata
        self.name = name
        self.type = type
        self.updatedAt = updatedAt
    }
}

/// Confirmation that a `memory_store` was deleted. Mirrors
/// `types/beta/beta_managed_agents_deleted_memory_store.py`, returned by `BetaMemoryStores.delete`.
public struct BetaManagedAgentsDeletedMemoryStore: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "memory_store_deleted") {
        self.id = id
        self.type = type
    }
}
