import Anthropic

/// Exposed as `client.beta.dreams`, mirroring `resources/beta/dreams.py`. Every method sends
/// `betaQuery` and merges in the mandatory `dreaming-2026-04-21` beta header via
/// `betaRequestOptions`. There is no `update`/`delete` -- a Dream is an immutable-once-created job
/// that can only be archived or canceled.
public struct BetaDreams: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "dreaming-2026-04-21"

    /// Create a Dream.
    public func create(
        _ params: BetaDreamCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaDream {
        try await client.transport.send(
            method: "POST",
            path: "v1/dreams",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a Dream by ID.
    public func retrieve(
        _ dreamId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaDream {
        try await client.transport.get(
            path: "v1/dreams/\(dreamId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List Dreams, most recently created first. `createdAtGt`/`createdAtLt` are pre-formatted
    /// ISO8601 timestamp strings, sent as the literal `created_at[gt]`/`created_at[lt]` query
    /// keys (exclusive bounds -- matching `dream_list_params.py`'s `PropertyInfo(alias=...)`
    /// aliases; unlike `BetaSessions.list`, there is no `gte`/`lte` variant). `statuses` is
    /// repeated as `statuses[]=...` per status, matching the bracket array format used elsewhere.
    public func list(
        createdAtGt: String? = nil,
        createdAtLt: String? = nil,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        statuses: [String]? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaDream> {
        try await client.transport.get(
            path: "v1/dreams",
            query: betaQuery.merging(
                [
                    "created_at[gt]": createdAtGt,
                    "created_at[lt]": createdAtLt,
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            arrayQuery: ["statuses": statuses],
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a Dream.
    public func archive(
        _ dreamId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaDream {
        try await client.transport.post(
            path: "v1/dreams/\(dreamId)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Cancel a Dream.
    public func cancel(
        _ dreamId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaDream {
        try await client.transport.post(
            path: "v1/dreams/\(dreamId)/cancel",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var dreams: BetaDreams { BetaDreams(client: client) }
}
