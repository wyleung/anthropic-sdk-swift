import Foundation
import Anthropic

/// Translates decoded SSE messages into `BetaManagedAgentsStreamSessionEvents` for the Managed
/// Agents session event stream (`client.beta.sessions.events.stream`). Same `ping`/`error` handling and
/// `type`-injection as `BetaMessagesSSE`.
///
/// Every named event with data is decoded: a name this port models into its typed case, anything else
/// into `.unknown(type:raw:)`. This used to be a hard-coded allowlist whose `default` dropped the rest,
/// so each new event type (the `workflow_run.*` family is the latest) was silently swallowed until
/// someone remembered to add its name here. Python 1.16.0 / TypeScript 0.136.0 removed the same
/// allowlist from their generic `Stream.__stream__`.
enum BetaSessionsSSE {
    /// The event names with typed cases. A *malformed* payload under one of these is a protocol fault
    /// and throws; under any other name it degrades to `.unknown` instead of failing the stream.
    private static let knownEventNames: Set<String> = [
        "user.message", "user.interrupt", "user.tool_confirmation", "user.custom_tool_result",
        "agent.custom_tool_use", "agent.message", "agent.thinking", "agent.mcp_tool_use",
        "agent.mcp_tool_result", "agent.tool_use", "agent.tool_result",
        "agent.thread_message_received", "agent.thread_message_sent",
        "agent.thread_context_compacted", "session.error", "session.status_rescheduled",
        "session.status_running", "session.status_idle", "session.status_terminated",
        "session.thread_created", "span.outcome_evaluation_start", "span.outcome_evaluation_end",
        "span.model_request_start", "span.model_request_end", "span.outcome_evaluation_ongoing",
        "user.define_outcome", "session.deleted", "session.thread_status_running",
        "session.thread_status_idle", "session.thread_status_terminated", "user.tool_result",
        "session.thread_status_rescheduled", "session.updated", "event_start", "event_delta",
        "system.message", "session.usage",
        "workflow_run.created", "workflow_run.status_running", "workflow_run.status_idle",
        "workflow_run.status_ended", "workflow_run.error", "workflow_run.phase_started",
        "workflow_run.phase_ended",
    ]

    static func translate(
        _ sse: ServerSentEvent, response: HTTPURLResponse
    ) throws -> BetaManagedAgentsStreamSessionEvents? {
        guard let event = sse.event, event != "ping" else { return nil }
        if event == "error" {
            let body = try? HTTPTransport.decoder.decode(JSONValue.self, from: Data(sse.data.utf8))
            throw AnthropicError.from(response: response, body: body)
        }
        guard !sse.data.isEmpty else { return nil }
        do {
            let data = try injectingType(sse.data, from: event)
            return try HTTPTransport.decoder.decode(BetaManagedAgentsStreamSessionEvents.self, from: data)
        } catch where !knownEventNames.contains(event) {
            return .unknown(type: event, raw: .string(sse.data))
        }
    }

    /// Wraps a raw SSE response into the translated event sequence, matching Python's
    /// `Stream[BetaManagedAgentsStreamSessionEvents]` -- a plain single-consumer async iterator with
    /// no accumulation or multi-subscriber support (unlike `BetaMessageStream`, which exists because
    /// Python's `messages.stream()` returns a dedicated `MessageStream` class offering several named
    /// views onto the same feed; `events.stream()` has no such counterpart).
    static func stream(
        response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>
    ) -> AsyncThrowingStream<BetaManagedAgentsStreamSessionEvents, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await sseEvent in sse {
                        if let event = try translate(sseEvent, response: response) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Mirrors Python's `if is_dict(data) and "type" not in data: data["type"] = sse.event`. See
    /// GA's `MessagesSSE.injectingType` for why this uses `JSONSerialization` directly rather than
    /// round-tripping through `JSONValue`.
    private static func injectingType(_ json: String, from event: String?) throws -> Data {
        let data = Data(json.utf8)
        guard let event else { return data }
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        guard object["type"] == nil else { return data }
        object["type"] = event
        return try JSONSerialization.data(withJSONObject: object)
    }
}
