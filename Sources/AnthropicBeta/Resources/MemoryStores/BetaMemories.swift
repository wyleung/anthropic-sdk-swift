import Anthropic

/// Exposed as `client.beta.memoryStores.memories`, mirroring `resources/beta/memory_stores/memories.py`.
///
/// `memoryStoreId` is always a plain Swift parameter, never a field on the params structs (matching
/// how the API treats it as a path parameter, not a body field). Following the two-id convention
/// established by `BetaVaultCredentials`, every method here that identifies a specific memory takes
/// `_ memoryId: String` positional first and `memoryStoreId: String` labeled second; `create` and
/// `list` have no memory id yet, so `memoryStoreId` is their only (labeled) identifier.
///
/// `view` selects the response projection (`basic` omits `content`, `full` populates it) and is
/// always a query parameter on the wire -- per `BetaManagedAgentsMemoryView`'s closed-Literal-used-
/// only-as-a-query-parameter treatment, it is a flat `String?` here rather than a dedicated enum.
public struct BetaMemories: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "agent-memory-2026-07-22"

    /// Create a memory.
    public func create(
        memoryStoreId: String,
        _ params: BetaMemoryCreateParams,
        view: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemory {
        try await client.transport.send(
            method: "POST",
            path: "v1/memory_stores/\(memoryStoreId)/memories",
            query: betaQuery.merging(["view": view]) { _, new in new },
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a memory by ID.
    public func retrieve(
        _ memoryId: String,
        memoryStoreId: String,
        view: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemory {
        try await client.transport.get(
            path: "v1/memory_stores/\(memoryStoreId)/memories/\(memoryId)",
            query: betaQuery.merging(["view": view]) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a memory. Every field in `params` is a PATCH-merge -- see `BetaMemoryUpdateParams` for
    /// the omit/preserve semantics of each field, and `BetaManagedAgentsPreconditionParam` for the
    /// optional optimistic-concurrency check.
    public func update(
        _ memoryId: String,
        memoryStoreId: String,
        _ params: BetaMemoryUpdateParams,
        view: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsMemory {
        try await client.transport.send(
            method: "POST",
            path: "v1/memory_stores/\(memoryStoreId)/memories/\(memoryId)",
            query: betaQuery.merging(["view": view]) { _, new in new },
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List memories under `memoryStoreId`, in path order. `depth` of `0` (or omitted) recurses
    /// fully (like `find`); `1` returns immediate children only, rolling deeper entries up as
    /// `memory_prefix` items (like `ls`). `pathPrefix` filters to a segment-aligned prefix (must end
    /// with `/`). `view: "full"` populates `content` on each `memory` item and caps `limit` at 20.
    public func list(
        memoryStoreId: String,
        depth: Int? = nil,
        limit: Int? = nil,
        page: String? = nil,
        pathPrefix: String? = nil,
        view: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsMemoryListItem> {
        try await client.transport.get(
            path: "v1/memory_stores/\(memoryStoreId)/memories",
            query: betaQuery.merging(
                [
                    "depth": depth.map(String.init),
                    "limit": limit.map(String.init),
                    "page": page,
                    "path_prefix": pathPrefix,
                    "view": view,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Delete a memory. Its version history persists and remains listable via
    /// `BetaMemoryVersions.list` until the store itself is deleted. `expectedContentSha256`, if
    /// supplied, makes the delete conditional on the memory's current stored content hash.
    public func delete(
        _ memoryId: String,
        memoryStoreId: String,
        expectedContentSha256: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeletedMemory {
        try await client.transport.delete(
            path: "v1/memory_stores/\(memoryStoreId)/memories/\(memoryId)",
            query: betaQuery.merging(["expected_content_sha256": expectedContentSha256]) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaMemoryStores {
    public var memories: BetaMemories { BetaMemories(client: client) }
}
