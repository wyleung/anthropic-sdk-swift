import Anthropic

/// Exposed as `client.beta.sessions`, mirroring `resources/beta/sessions/sessions.py`. Every
/// method sends `betaQuery` and merges in the mandatory `managed-agents-2026-04-01` beta header
/// via `betaRequestOptions`. `list` returns `BidirectionalPageCursor`, not the ordinary
/// `PageCursor` -- Python's `sessions.py` imports `SyncBidirectionalPageCursor` specifically for
/// this endpoint, unlike every other list endpoint in this port so far.
public struct BetaSessions: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Create a new session.
    public func create(
        _ params: BetaSessionCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSession {
        try await client.transport.send(
            method: "POST",
            path: "v1/sessions",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a session by ID.
    public func retrieve(
        _ sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSession {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a session. Only `agent.tools`/`agent.mcpServers` are updatable and are a full
    /// replacement, not a merge -- see `BetaManagedAgentsSessionAgentUpdateParam`. Every other
    /// field in `params` is a PATCH-merge -- see `BetaSessionUpdateParams` for the omit/null/value
    /// semantics of each field.
    public func update(
        _ sessionId: String,
        _ params: BetaSessionUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSession {
        try await client.transport.send(
            method: "POST",
            path: "v1/sessions/\(sessionId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List sessions, most recently created first by default. `createdAtGt`/`createdAtGte`/
    /// `createdAtLt`/`createdAtLte` are pre-formatted ISO8601 timestamp strings, sent as the
    /// literal `created_at[gt]`/`created_at[gte]`/`created_at[lt]`/`created_at[lte]` query keys
    /// (matching `session_list_params.py`'s `PropertyInfo(alias=...)` aliases). `statuses` is
    /// repeated as `statuses[]=...` per status, matching the bracket array format used elsewhere.
    public func list(
        agentId: String? = nil,
        agentVersion: Int? = nil,
        createdAtGt: String? = nil,
        createdAtGte: String? = nil,
        createdAtLt: String? = nil,
        createdAtLte: String? = nil,
        deploymentId: String? = nil,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        memoryStoreId: String? = nil,
        order: String? = nil,
        page: String? = nil,
        statuses: [String]? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BidirectionalPageCursor<BetaManagedAgentsSession> {
        try await client.transport.get(
            path: "v1/sessions",
            query: betaQuery.merging(
                [
                    "agent_id": agentId,
                    "agent_version": agentVersion.map(String.init),
                    "created_at[gt]": createdAtGt,
                    "created_at[gte]": createdAtGte,
                    "created_at[lt]": createdAtLt,
                    "created_at[lte]": createdAtLte,
                    "deployment_id": deploymentId,
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "memory_store_id": memoryStoreId,
                    "order": order,
                    "page": page,
                ]
            ) { _, new in new },
            arrayQuery: ["statuses": statuses],
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Permanently delete a session.
    public func delete(
        _ sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeletedSession {
        try await client.transport.delete(
            path: "v1/sessions/\(sessionId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a session.
    public func archive(
        _ sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSession {
        try await client.transport.post(
            path: "v1/sessions/\(sessionId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var sessions: BetaSessions { BetaSessions(client: client) }
}
