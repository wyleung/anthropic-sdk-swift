/// Mirrors `types/beta/memory_store_update_params.py`. `description` and `name` are plain 2-state
/// fields (omit to preserve, pass a value -- including `""` for `description` -- to replace);
/// `metadata` is the standard per-key patch (outer `nil` omits the field, a present dictionary's
/// `nil` values delete that key, non-nil values upsert it).
public struct BetaMemoryStoreUpdateParams: Encodable, Sendable, Equatable {
    public var description: String?
    public var metadata: [String: String?]?
    public var name: String?

    public init(description: String? = nil, metadata: [String: String?]? = nil, name: String? = nil) {
        self.description = description
        self.metadata = metadata
        self.name = name
    }
}
