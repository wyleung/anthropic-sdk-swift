/// A `memory` object: a single text document at a hierarchical path inside a memory store.
/// `content` is populated when `view=full` and `nil` when `view=basic`; `contentSizeBytes` and
/// `contentSha256` are always populated so sync clients can diff without fetching content.
/// Memories are addressed by their `mem_...` ID; the path is the create key and can be changed via
/// update. Mirrors `types/beta/memory_stores/beta_managed_agents_memory.py`.
public struct BetaManagedAgentsMemory: Codable, Sendable, Equatable {
    public let id: String
    public let contentSha256: String
    public let contentSizeBytes: Int
    public let createdAt: String
    public let memoryStoreId: String
    public let memoryVersionId: String
    public let path: String
    public let type: String
    public let updatedAt: String
    public let content: String?

    public init(
        id: String,
        contentSha256: String,
        contentSizeBytes: Int,
        createdAt: String,
        memoryStoreId: String,
        memoryVersionId: String,
        path: String,
        type: String = "memory",
        updatedAt: String,
        content: String? = nil
    ) {
        self.id = id
        self.contentSha256 = contentSha256
        self.contentSizeBytes = contentSizeBytes
        self.createdAt = createdAt
        self.memoryStoreId = memoryStoreId
        self.memoryVersionId = memoryVersionId
        self.path = path
        self.type = type
        self.updatedAt = updatedAt
        self.content = content
    }
}
