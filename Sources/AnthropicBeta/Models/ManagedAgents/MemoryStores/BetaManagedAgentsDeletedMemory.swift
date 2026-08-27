/// Tombstone returned by `BetaMemories.delete`. The memory's version history persists and remains
/// listable via `BetaMemoryVersions.list` until the store itself is deleted. Mirrors
/// `types/beta/memory_stores/beta_managed_agents_deleted_memory.py`.
public struct BetaManagedAgentsDeletedMemory: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "memory_deleted") {
        self.id = id
        self.type = type
    }
}
