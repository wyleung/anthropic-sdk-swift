/// Ported from `beta_managed_agents_credential_validation.py`, returned by
/// `BetaVaultCredentials.mcpOauthValidate`.
public struct BetaManagedAgentsCredentialValidation: Codable, Sendable, Equatable {
    public let credentialId: String
    public let hasRefreshToken: Bool
    public let mcpProbe: BetaManagedAgentsMCPProbe?
    public let refresh: BetaManagedAgentsRefreshObject?
    public let status: BetaManagedAgentsCredentialValidationStatus
    public let type: String
    public let validatedAt: String
    public let vaultId: String

    public init(
        credentialId: String,
        hasRefreshToken: Bool,
        mcpProbe: BetaManagedAgentsMCPProbe? = nil,
        refresh: BetaManagedAgentsRefreshObject? = nil,
        status: BetaManagedAgentsCredentialValidationStatus,
        type: String = "vault_credential_validation",
        validatedAt: String,
        vaultId: String
    ) {
        self.credentialId = credentialId
        self.hasRefreshToken = hasRefreshToken
        self.mcpProbe = mcpProbe
        self.refresh = refresh
        self.status = status
        self.type = type
        self.validatedAt = validatedAt
        self.vaultId = vaultId
    }
}
