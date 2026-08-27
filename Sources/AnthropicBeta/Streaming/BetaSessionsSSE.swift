import Foundation
import Anthropic

/// Translates decoded SSE messages into `BetaManagedAgentsStreamSessionEvents` for the Managed
/// Agents session event stream (`client.beta.sessions.events.stream`). Same
/// `ping`/`error`/forward-compatible-drop handling and `type`-injection as `BetaMessagesSSE` --
/// ported from the shared event-name dispatch in Python's generic `Stream.__stream__`
/// (`_streaming.py`), scoped down to just the event names that appear in
/// `BetaManagedAgentsStreamSessionEvents`'s 37-member union.
enum BetaSessionsSSE {
    static func translate(
        _ sse: ServerSentEvent, response: HTTPURLResponse
    ) throws -> BetaManagedAgentsStreamSessionEvents? {
        switch sse.event {
        case "ping":
            return nil
        case "error":
            let body = try? HTTPTransport.decoder.decode(JSONValue.self, from: Data(sse.data.utf8))
            throw AnthropicError.from(response: response, body: body)
        case "user.message", "user.interrupt", "user.tool_confirmation", "user.custom_tool_result",
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
            "system.message", "session.usage":
            let data = try injectingType(sse.data, from: sse.event)
            return try HTTPTransport.decoder.decode(BetaManagedAgentsStreamSessionEvents.self, from: data)
        default:
            return nil
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
