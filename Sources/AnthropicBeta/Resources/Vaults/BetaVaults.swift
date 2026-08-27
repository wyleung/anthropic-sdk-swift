import Anthropic

/// Exposed as `client.beta.vaults`, mirroring `resources/beta/vaults/vaults.py`. Every method sends
/// `betaQuery` and merges in the mandatory `managed-agents-2026-04-01` beta header via
/// `betaRequestOptions`. `credentials` is exposed as a nested resource on `BetaVaults` itself, via
/// the accessor in `BetaVaultCredentials.swift`.
public struct BetaVaults: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Create a vault.
    public func create(
        _ params: BetaVaultCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsVault {
        try await client.transport.send(
            method: "POST",
            path: "v1/vaults",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a vault by ID.
    public func retrieve(
        _ vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsVault {
        try await client.transport.get(
            path: "v1/vaults/\(vaultId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a vault. Every field in `params` is a PATCH-merge -- see `BetaVaultUpdateParams` for
    /// the omit/preserve/clear semantics of each field.
    public func update(
        _ vaultId: String,
        _ params: BetaVaultUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsVault {
        try await client.transport.send(
            method: "POST",
            path: "v1/vaults/\(vaultId)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List vaults, most recently created first.
    public func list(
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsVault> {
        try await client.transport.get(
            path: "v1/vaults",
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

    /// Delete a vault.
    public func delete(
        _ vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeletedVault {
        try await client.transport.delete(
            path: "v1/vaults/\(vaultId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a vault.
    public func archive(
        _ vaultId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsVault {
        try await client.transport.post(
            path: "v1/vaults/\(vaultId)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var vaults: BetaVaults { BetaVaults(client: client) }
}
