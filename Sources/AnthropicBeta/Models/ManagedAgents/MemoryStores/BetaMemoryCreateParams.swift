/// Request body for `BetaMemories.create`. `view` is a query parameter, not part of the body, so
/// it is a flat method parameter rather than a property here. Mirrors
/// `types/beta/memory_stores/memory_create_params.py`.
public struct BetaMemoryCreateParams: Encodable, Sendable, Equatable {
    public var content: String
    public var path: String

    public init(content: String, path: String) {
        self.content = content
        self.path = path
    }
}
