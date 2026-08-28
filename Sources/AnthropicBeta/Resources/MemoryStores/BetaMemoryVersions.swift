import Anthropic

/// Exposed as `client.beta.memoryStores.memoryVersions`, mirroring
/// `resources/beta/memory_stores/memory_versions.py`. Read-only plus `redact` -- versions are an
/// immutable, append-only history, so there is no create/update/delete.
///
/// `memoryStoreId` is always a plain Swift parameter, never a field on the params structs.
/// Following the two-id convention established by `BetaMemories`/`BetaVaultCredentials`, `retrieve`
/// and `redact` take `_ memoryVersionId: String` positional first and `memoryStoreId: String`
/// labeled second; `list` has no version id yet, so `memoryStoreId` is its only (labeled)
/// identifier. `view`/`operation` are flat `String?` query parameters -- matching how `status` on
/// `BetaDeployments.list` and `triggerType` on `BetaDeploymentRuns.list` stay flat strings even
/// though a dedicated response-payload enum exists for the same underlying field.
public struct BetaMemoryVersions: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "agent-memory-2026-07-22"

    /// Retrieve a memory version by ID. A redacted version returns 200 with `content`, `path`,
    /// `contentSizeBytes`, and `contentSha256` all `nil`; branch on `redactedAt`, not HTTP status.
    public func retrieve(
        _ memoryVersionId: String,
        memoryStoreId: String,
        view: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemoryVersion {
        try await client.transport.get(
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)/memory_versions/\(memoryVersionId.asPathComponent)",
            query: betaQuery.merging(["view": view]) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List memory versions under `memoryStoreId`, most recently created first. `memoryId` scopes
    /// to a single memory's lineage (including its `deleted` row if it was removed);
    /// `createdAtGte`/`createdAtLte` are inclusive bounds.
    public func list(
        memoryStoreId: String,
        apiKeyId: String? = nil,
        createdAtGte: String? = nil,
        createdAtLte: String? = nil,
        limit: Int? = nil,
        memoryId: String? = nil,
        operation: String? = nil,
        page: String? = nil,
        serviceAccountId: String? = nil,
        sessionId: String? = nil,
        view: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsMemoryVersion> {
        try await client.transport.get(
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)/memory_versions",
            query: betaQuery.merging(
                [
                    "api_key_id": apiKeyId,
                    "created_at[gte]": createdAtGte,
                    "created_at[lte]": createdAtLte,
                    "limit": limit.map(String.init),
                    "memory_id": memoryId,
                    "operation": operation,
                    "page": page,
                    "service_account_id": serviceAccountId,
                    "session_id": sessionId,
                    "view": view,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Redact a memory version, clearing `content`/`path`/`contentSizeBytes`/`contentSha256` and
    /// setting `redactedAt`/`redactedBy`. Irreversible.
    public func redact(
        _ memoryVersionId: String,
        memoryStoreId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemoryVersion {
        try await client.transport.post(
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)/memory_versions/\(memoryVersionId.asPathComponent)/redact",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaMemoryStores {
    public var memoryVersions: BetaMemoryVersions { BetaMemoryVersions(client: client) }
}
