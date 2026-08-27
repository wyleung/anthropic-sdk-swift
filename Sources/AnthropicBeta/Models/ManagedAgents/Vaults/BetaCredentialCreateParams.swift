/// Ported from `credential_create_params.py`. `vault_id` is a path parameter on
/// `BetaVaultCredentials.create`, not a field here -- see that resource for why.
public struct BetaCredentialCreateParams: Encodable, Sendable, Equatable {
    public let auth: BetaCredentialAuthCreateParams
    public let displayName: String?
    public let metadata: [String: String]?

    public init(
        auth: BetaCredentialAuthCreateParams,
        displayName: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.auth = auth
        self.displayName = displayName
        self.metadata = metadata
    }
}
