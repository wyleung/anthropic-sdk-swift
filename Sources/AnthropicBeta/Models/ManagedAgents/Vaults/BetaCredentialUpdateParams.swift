/// Ported from `credential_update_params.py`. `vault_id` is a path parameter on
/// `BetaVaultCredentials.update`, not a field here -- see that resource for why. `metadata` is a
/// standard per-key patch: a present key set to `nil` deletes it, omitting the field entirely
/// preserves all existing metadata.
public struct BetaCredentialUpdateParams: Encodable, Sendable, Equatable {
    public let auth: BetaCredentialAuthUpdateParams?
    public let displayName: String?
    public let metadata: [String: String?]?

    public init(
        auth: BetaCredentialAuthUpdateParams? = nil,
        displayName: String? = nil,
        metadata: [String: String?]? = nil
    ) {
        self.auth = auth
        self.displayName = displayName
        self.metadata = metadata
    }
}
