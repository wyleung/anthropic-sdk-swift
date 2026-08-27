/// A `memory_version` object: one immutable, attributed row in a memory's append-only history.
/// Every non-no-op mutation to a memory produces a new version. Versions belong to the store (not
/// the individual memory) and persist after the memory is deleted. Retrieving a redacted version
/// returns 200 with `content`, `path`, `contentSizeBytes`, and `contentSha256` all `nil`; branch on
/// `redactedAt`, not HTTP status. Mirrors `types/beta/memory_stores/beta_managed_agents_memory_version.py`.
public struct BetaManagedAgentsMemoryVersion: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let memoryId: String
    public let memoryStoreId: String
    public let operation: BetaManagedAgentsMemoryVersionOperation
    public let type: String
    public let content: String?
    public let contentSha256: String?
    public let contentSizeBytes: Int?
    public let createdBy: BetaManagedAgentsActor?
    public let path: String?
    public let redactedAt: String?
    public let redactedBy: BetaManagedAgentsActor?

    public init(
        id: String,
        createdAt: String,
        memoryId: String,
        memoryStoreId: String,
        operation: BetaManagedAgentsMemoryVersionOperation,
        type: String = "memory_version",
        content: String? = nil,
        contentSha256: String? = nil,
        contentSizeBytes: Int? = nil,
        createdBy: BetaManagedAgentsActor? = nil,
        path: String? = nil,
        redactedAt: String? = nil,
        redactedBy: BetaManagedAgentsActor? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.memoryId = memoryId
        self.memoryStoreId = memoryStoreId
        self.operation = operation
        self.type = type
        self.content = content
        self.contentSha256 = contentSha256
        self.contentSizeBytes = contentSizeBytes
        self.createdBy = createdBy
        self.path = path
        self.redactedAt = redactedAt
        self.redactedBy = redactedBy
    }
}
