import Anthropic

/// Exposed as `client.beta.vaults.credentials`, mirroring `resources/beta/vaults/credentials.py`.
///
/// `vaultId` is always a plain Swift parameter, never a field on the params structs (matching how
/// the API treats it as a path parameter, not a body field). Following the two-id convention
/// established by `BetaSessionThreads` (its own resource id unlabeled-positional first, its
/// parent's id labeled second), every method here that identifies a specific credential takes
/// `_ credentialId: String` positional first and `vaultId: String` labeled second; `create` and
/// `list` have no credential id yet, so `vaultId` is their only (labeled) identifier.
public struct BetaVaultCredentials: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Create a credential within a vault.
    public func create(
        vaultId: String,
        _ params: BetaCredentialCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsCredential {
        try await client.transport.send(
            method: "POST",
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a credential by ID.
    public func retrieve(
        _ credentialId: String,
        vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsCredential {
        try await client.transport.get(
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials/\(credentialId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a credential. Every field in `params` is a PATCH-merge -- see `BetaCredentialUpdateParams`
    /// for the omit/preserve/clear semantics of each field.
    public func update(
        _ credentialId: String,
        vaultId: String,
        _ params: BetaCredentialUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsCredential {
        try await client.transport.send(
            method: "POST",
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials/\(credentialId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List credentials within a vault, most recently created first.
    public func list(
        vaultId: String,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsCredential> {
        try await client.transport.get(
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials",
            query: betaQuery.merging(
                [
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Delete a credential.
    public func delete(
        _ credentialId: String,
        vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeletedCredential {
        try await client.transport.delete(
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials/\(credentialId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a credential.
    public func archive(
        _ credentialId: String,
        vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsCredential {
        try await client.transport.post(
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials/\(credentialId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Validate an `mcp_oauth` credential by probing its MCP server and, if a refresh token is
    /// present, attempting a refresh-token exchange.
    public func mcpOauthValidate(
        _ credentialId: String,
        vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsCredentialValidation {
        try await client.transport.post(
            path: "v1/vaults/\(vaultId.asPathComponent)/credentials/\(credentialId.asPathComponent)/mcp_oauth_validate",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaVaults {
    public var credentials: BetaVaultCredentials { BetaVaultCredentials(client: client) }
}
