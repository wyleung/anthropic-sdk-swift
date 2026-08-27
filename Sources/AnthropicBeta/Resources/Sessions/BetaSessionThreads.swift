import Anthropic

/// Exposed as `client.beta.sessions.threads`, mirroring
/// `resources/beta/sessions/threads/threads.py`. Read-only (retrieve/list/archive) -- threads are
/// created implicitly by the session, never via a client call. Python's `threads.py` also wires an
/// `events` sub-resource; that belongs to Slice 4 (streaming) per the governing plan and is
/// deliberately not ported here.
public struct BetaSessionThreads: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Retrieve a session thread by ID.
    public func retrieve(
        _ threadId: String,
        sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSessionThread {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId)/threads/\(threadId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List threads within a session. Forward-only pagination -- defaults to 1000 results per page.
    public func list(
        sessionId: String,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsSessionThread> {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId)/threads",
            query: betaQuery.merging(
                [
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a session thread.
    public func archive(
        _ threadId: String,
        sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSessionThread {
        try await client.transport.post(
            path: "v1/sessions/\(sessionId)/threads/\(threadId)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaSessions {
    public var threads: BetaSessionThreads { BetaSessionThreads(client: client) }
}
