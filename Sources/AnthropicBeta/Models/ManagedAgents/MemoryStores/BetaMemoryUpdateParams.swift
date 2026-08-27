/// Request body for `BetaMemories.update`. All fields are plain 2-state (omit to leave unchanged);
/// `view` is a query parameter and is a flat method parameter rather than a property here. Mirrors
/// `types/beta/memory_stores/memory_update_params.py`.
public struct BetaMemoryUpdateParams: Encodable, Sendable, Equatable {
    public var content: String?
    public var path: String?
    public var precondition: BetaManagedAgentsPreconditionParam?

    public init(
        content: String? = nil,
        path: String? = nil,
        precondition: BetaManagedAgentsPreconditionParam? = nil
    ) {
        self.content = content
        self.path = path
        self.precondition = precondition
    }
}
