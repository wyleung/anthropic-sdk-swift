import Anthropic

/// Exposed as `client.beta.environments.work`, mirroring
/// `resources/beta/environments/work.py`. These endpoints are invoked automatically by the
/// pre-built environment worker Anthropic provides for orchestrating self-hosted sandbox sessions
/// -- they're included here as REST primitives (per the approved Phase 7 plan's decision to ship
/// the REST surface now and defer any local-process poller/worker convenience wrapper).
public struct BetaEnvironmentWork: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Retrieve a work item by ID.
    public func retrieve(
        environmentId: String,
        workId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWork {
        try await client.transport.get(
            path: "v1/environments/\(environmentId.asPathComponent)/work/\(workId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Patch a work item's metadata -- see `BetaWorkUpdateParams` for the per-key upsert/delete
    /// semantics.
    public func update(
        environmentId: String,
        workId: String,
        _ params: BetaWorkUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWork {
        try await client.transport.send(
            method: "POST",
            path: "v1/environments/\(environmentId.asPathComponent)/work/\(workId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List work items for an environment.
    public func list(
        environmentId: String,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaSelfHostedWork> {
        try await client.transport.get(
            path: "v1/environments/\(environmentId.asPathComponent)/work",
            query: betaQuery.merging(
                [
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Acknowledge a work item, assigning it to the calling self-hosted sandbox.
    public func ack(
        environmentId: String,
        workId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWork {
        try await client.transport.post(
            path: "v1/environments/\(environmentId.asPathComponent)/work/\(workId.asPathComponent)/ack",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Record a heartbeat for a work item, extending its lease. Sent as query parameters, not a
    /// JSON body -- matching `work.py`'s `heartbeat`, which passes no `body=` argument. Use the
    /// literal `"NO_HEARTBEAT"` for `expectedLastHeartbeat` to claim an unclaimed lease; for
    /// subsequent heartbeats, echo back the server's previous `lastHeartbeat` value exactly
    /// (optimistic concurrency -- a mismatch returns 412 Precondition Failed).
    public func heartbeat(
        environmentId: String,
        workId: String,
        desiredTtlSeconds: Int? = nil,
        expectedLastHeartbeat: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWorkHeartbeatResponse {
        try await client.transport.post(
            path: "v1/environments/\(environmentId.asPathComponent)/work/\(workId.asPathComponent)/heartbeat",
            query: betaQuery.merging(
                [
                    "desired_ttl_seconds": desiredTtlSeconds.map(String.init),
                    "expected_last_heartbeat": expectedLastHeartbeat,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Long-poll for work items in the queue. Returns `nil` if the poll times out with no work
    /// available. `workerId` is sent as the mixed-case `Anthropic-Worker-ID` header (not a query
    /// parameter or body field), used to track aggregated environment-level work metrics.
    public func poll(
        environmentId: String,
        blockMs: Int? = nil,
        reclaimOlderThanMs: Int? = nil,
        workerId: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWork? {
        var options = options
        if let workerId {
            options.headers["Anthropic-Worker-ID"] = workerId
        }
        return try await client.transport.get(
            path: "v1/environments/\(environmentId.asPathComponent)/work/poll",
            query: betaQuery.merging(
                [
                    "block_ms": blockMs.map(String.init),
                    "reclaim_older_than_ms": reclaimOlderThanMs.map(String.init),
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Fetch work queue statistics for an environment.
    public func stats(
        environmentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWorkQueueStats {
        try await client.transport.get(
            path: "v1/environments/\(environmentId.asPathComponent)/work/stats",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Stop a work item.
    public func stop(
        environmentId: String,
        workId: String,
        force: Bool? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSelfHostedWork {
        try await client.transport.send(
            method: "POST",
            path: "v1/environments/\(environmentId.asPathComponent)/work/\(workId.asPathComponent)/stop",
            query: betaQuery,
            body: BetaWorkStopParams(force: force),
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaEnvironments {
    public var work: BetaEnvironmentWork { BetaEnvironmentWork(client: client) }
}
