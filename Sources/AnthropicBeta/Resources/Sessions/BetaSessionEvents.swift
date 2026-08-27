import Foundation
import Anthropic

/// Exposed as `client.beta.sessions.events`, mirroring `resources/beta/sessions/events.py`. Every
/// method sends `betaQuery` and merges in the mandatory `managed-agents-2026-04-01` beta header via
/// `betaRequestOptions`. `toolRunner(...)` constructs Python's event-sourced session tool runner --
/// see `SessionToolRunner` for the implementation.
public struct BetaSessionEvents: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// List events for a session, oldest first by default. `createdAtGt`/`createdAtGte`/
    /// `createdAtLt`/`createdAtLte` are pre-formatted ISO8601 timestamp strings, sent as the literal
    /// `created_at[gt]`/`created_at[gte]`/`created_at[lt]`/`created_at[lte]` query keys (matching
    /// `event_list_params.py`'s `PropertyInfo(alias=...)` aliases), compared against each event's
    /// `processedAt`. `types` is repeated as `types[]=...` per type, matching `BetaSessions.list`'s
    /// `statuses[]` convention.
    public func list(
        sessionId: String,
        createdAtGt: String? = nil,
        createdAtGte: String? = nil,
        createdAtLt: String? = nil,
        createdAtLte: String? = nil,
        limit: Int? = nil,
        order: String? = nil,
        page: String? = nil,
        types: [String]? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsSessionEvent> {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId)/events",
            query: betaQuery.merging(
                [
                    "created_at[gt]": createdAtGt,
                    "created_at[gte]": createdAtGte,
                    "created_at[lt]": createdAtLt,
                    "created_at[lte]": createdAtLte,
                    "limit": limit.map(String.init),
                    "order": order,
                    "page": page,
                ]
            ) { _, new in new },
            arrayQuery: ["types": types],
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Send one or more events to a session.
    public func send(
        sessionId: String,
        events: [BetaManagedAgentsEventParams],
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSendSessionEvents {
        try await client.transport.send(
            method: "POST",
            path: "v1/sessions/\(sessionId)/events",
            query: betaQuery,
            body: BetaSessionEventSendParams(events: events),
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Open a live SSE connection to a session's events. `eventDeltas` opts into `event_start`/
    /// `event_delta` previews for the given event types (`"agent.message"`/`"agent.thinking"`)
    /// before their buffered final event arrives -- see `accumulateManagedAgentsEvent` to fold
    /// those previews back into a snapshot. The returned stream is a plain single-consumer
    /// sequence -- see `BetaSessionsSSE.stream` for why this doesn't wrap it in a dedicated class
    /// the way `BetaMessages.stream()` does.
    public func stream(
        sessionId: String,
        eventDeltas: [String]? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> AsyncThrowingStream<BetaManagedAgentsStreamSessionEvents, Error> {
        let (response, sse) = try await client.transport.stream(
            method: "GET",
            path: "v1/sessions/\(sessionId)/events/stream",
            query: betaQuery,
            arrayQuery: ["event_deltas": eventDeltas],
            body: Data(),
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
        return BetaSessionsSSE.stream(response: response, sse: sse)
    }

    /// Builds a `SessionToolRunner` that watches this session's events, dispatches
    /// `agent.tool_use`/`agent.custom_tool_use` events to `tools`, and posts results back --
    /// mirroring `BetaMessages.toolRunner`'s factory shape. `maxIdle` stops the runner after this
    /// many seconds of session inactivity following an `end_turn` idle event (`nil` disables the
    /// idle watchdog entirely). `environmentKey` scopes every request the runner makes to a
    /// `self_hosted` environment's own bearer token instead of the client's API key.
    public func toolRunner(
        sessionId: String,
        tools: [AnyAnthropicTool],
        maxIdle: TimeInterval? = 60,
        environmentKey: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) -> SessionToolRunner {
        SessionToolRunner(
            client: client, sessionId: sessionId, tools: tools, maxIdle: maxIdle,
            environmentKey: environmentKey, betas: betas, options: options
        )
    }
}

extension BetaSessions {
    public var events: BetaSessionEvents { BetaSessionEvents(client: client) }
}
