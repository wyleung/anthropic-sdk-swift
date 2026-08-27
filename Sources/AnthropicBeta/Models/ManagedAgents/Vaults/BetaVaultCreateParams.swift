/// Mirrors `types/beta/vault_create_params.py`.
public struct BetaVaultCreateParams: Encodable, Sendable, Equatable {
    public var displayName: String
    public var metadata: [String: String]?

    public init(displayName: String, metadata: [String: String]? = nil) {
        self.displayName = displayName
        self.metadata = metadata
    }
}
