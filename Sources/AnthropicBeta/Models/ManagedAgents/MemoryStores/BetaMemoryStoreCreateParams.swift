/// Mirrors `types/beta/memory_store_create_params.py`.
public struct BetaMemoryStoreCreateParams: Encodable, Sendable, Equatable {
    public var name: String
    public var description: String?
    public var metadata: [String: String]?

    public init(name: String, description: String? = nil, metadata: [String: String]? = nil) {
        self.name = name
        self.description = description
        self.metadata = metadata
    }
}
