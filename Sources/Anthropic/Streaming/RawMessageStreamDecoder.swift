import Foundation

/// Translates decoded SSE messages into `RawMessageStreamEvent`s for the Messages API. This is
/// the Messages-specific layer above the generic `SSEDecoder`: `ping`, unnamed events and events
/// with no data are skipped, `error` throws, and every other named event is decoded -- the 6
/// Messages event names into their typed cases, anything else into `.unknown(type:raw:)`.
///
/// Unrecognized names used to be dropped as forward-compatible no-ops, matching the reference
/// SDKs' old hard-coded allowlist in `__stream__`/`_iterSSEMessages`; Python 1.16.0 and TypeScript
/// 0.136.0 now yield them instead, so a new event type is visible to the caller rather than silent.
enum MessagesSSE {
    private static let knownEventNames: Set<String> = [
        "message_start", "message_delta", "message_stop",
        "content_block_start", "content_block_delta", "content_block_stop",
    ]

    static func translate(_ sse: ServerSentEvent, response: HTTPURLResponse) throws -> RawMessageStreamEvent? {
        guard let event = sse.event, event != "ping" else { return nil }
        if event == "error" {
            let body = try? HTTPTransport.decoder.decode(JSONValue.self, from: Data(sse.data.utf8))
            throw AnthropicError.from(response: response, body: body)
        }
        guard !sse.data.isEmpty else { return nil }
        do {
            let data = try injectingType(sse.data, from: event)
            return try HTTPTransport.decoder.decode(RawMessageStreamEvent.self, from: data)
        } catch where !knownEventNames.contains(event) {
            // A payload we can't make sense of under a name we don't recognize must not take down
            // the whole stream (Python would raise here); hand it over verbatim instead. A
            // malformed event with a *known* name still throws -- that's a real protocol fault.
            return .unknown(type: event, raw: .string(sse.data))
        }
    }

    /// Mirrors Python's `if is_dict(data) and "type" not in data: data["type"] = sse.event`: some
    /// payloads rely on the SSE `event:` name rather than repeating it as a `type` field. Uses
    /// `JSONSerialization` directly on the raw wire bytes rather than round-tripping through
    /// `JSONValue`, whose decode goes through the ambient `.convertFromSnakeCase` strategy --
    /// that strategy rewrites every object key it sees, including arbitrary nested keys inside a
    /// generic payload, not just ones matched against a `CodingKeys` enum. Operating on
    /// `[String: Any]` from `JSONSerialization` leaves wire keys untouched.
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
