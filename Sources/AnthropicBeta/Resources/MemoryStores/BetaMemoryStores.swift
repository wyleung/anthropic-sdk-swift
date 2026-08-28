import Anthropic

/// Exposed as `client.beta.memoryStores`, mirroring `resources/beta/memory_stores/memory_stores.py`.
/// Every method sends `betaQuery` and merges in the mandatory `agent-memory-2026-07-22` beta header
/// via `betaRequestOptions`. `memories`/`memoryVersions` are exposed as nested resources on
/// `BetaMemoryStores` itself, via the accessors in their own files.
public struct BetaMemoryStores: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "agent-memory-2026-07-22"

    /// Create a memory store.
    public func create(
        _ params: BetaMemoryStoreCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemoryStore {
        try await client.transport.send(
            method: "POST",
            path: "v1/memory_stores",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a memory store by ID.
    public func retrieve(
        _ memoryStoreId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemoryStore {
        try await client.transport.get(
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a memory store. Every field in `params` is a PATCH-merge -- see
    /// `BetaMemoryStoreUpdateParams` for the omit/preserve/clear semantics of each field.
    public func update(
        _ memoryStoreId: String,
        _ params: BetaMemoryStoreUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemoryStore {
        try await client.transport.send(
            method: "POST",
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List memory stores, most recently created first. `createdAtGte`/`createdAtLte` are
    /// pre-formatted ISO8601 timestamp strings, sent as the literal `created_at[gte]`/
    /// `created_at[lte]` query keys (inclusive bounds, unlike Dream's exclusive-only pair).
    public func list(
        createdAtGte: String? = nil,
        createdAtLte: String? = nil,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsMemoryStore> {
        try await client.transport.get(
            path: "v1/memory_stores",
            query: betaQuery.merging(
                [
                    "created_at[gte]": createdAtGte,
                    "created_at[lte]": createdAtLte,
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Delete a memory store.
    public func delete(
        _ memoryStoreId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeletedMemoryStore {
        try await client.transport.delete(
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a memory store.
    public func archive(
        _ memoryStoreId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemoryStore {
        try await client.transport.post(
            path: "v1/memory_stores/\(memoryStoreId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var memoryStores: BetaMemoryStores { BetaMemoryStores(client: client) }
}
