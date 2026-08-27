/// Mirrors `types/beta/vault_update_params.py`. `displayName` is a plain 2-state field (omit vs.
/// replace); `metadata` is the standard per-key patch (outer `nil` omits the field, a present
/// dictionary's `nil` values clear that key, non-nil values replace it).
public struct BetaVaultUpdateParams: Encodable, Sendable, Equatable {
    public var displayName: String?
    public var metadata: [String: String?]?

    public init(displayName: String? = nil, metadata: [String: String?]? = nil) {
        self.displayName = displayName
        self.metadata = metadata
    }
}
