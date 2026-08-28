import Foundation
import Anthropic

/// Exposed as `client.beta.sessions.threads.events`, mirroring
/// `resources/beta/sessions/threads/events.py`. Read-only (list/stream, no `send`) -- events are
/// only ever sent to the session as a whole, never to an individual thread.
public struct BetaSessionThreadEvents: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// List events for one thread within a session, oldest first by default. Unlike
    /// `BetaSessionEvents.list`, Python's `threads/events.py` exposes no `created_at`/`types`
    /// filters here -- confirmed by reading the file directly, not assumed from the parity of the
    /// two endpoints.
    public func list(
        _ threadId: String,
        sessionId: String,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsSessionEvent> {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId.asPathComponent)/threads/\(threadId.asPathComponent)/events",
            query: betaQuery.merging(
                [
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Open a live SSE connection to one thread's events. Note the path is `.../threads/{id}/stream`,
    /// not `.../threads/{id}/events/stream` -- confirmed directly against `threads/events.py` rather
    /// than assumed from `BetaSessionEvents.stream`'s `.../events/stream` shape.
    public func stream(
        _ threadId: String,
        sessionId: String,
        eventDeltas: [String]? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> AsyncThrowingStream<BetaManagedAgentsStreamSessionThreadEvents, Error> {
        let (response, sse) = try await client.transport.stream(
            method: "GET",
            path: "v1/sessions/\(sessionId.asPathComponent)/threads/\(threadId.asPathComponent)/stream",
            query: betaQuery,
            arrayQuery: ["event_deltas": eventDeltas],
            body: Data(),
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
        return BetaSessionsSSE.stream(response: response, sse: sse)
    }
}

extension BetaSessionThreads {
    public var events: BetaSessionThreadEvents { BetaSessionThreadEvents(client: client) }
}
