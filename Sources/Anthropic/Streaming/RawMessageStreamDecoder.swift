import Foundation

/// Translates decoded SSE messages into `RawMessageStreamEvent`s for the Messages API. This is
/// the Messages-specific layer above the generic `SSEDecoder`: it knows about `ping`/`error` and
/// the 6 Messages event names, and drops everything else (the Managed-Agents event vocabulary,
/// the deprecated text-completions `completion` event, and any unrecognized name) as
/// forward-compatible no-ops -- matching both reference SDKs' `_iterSSEMessages`/`__stream__`.
enum MessagesSSE {
    static func translate(_ sse: ServerSentEvent, response: HTTPURLResponse) throws -> RawMessageStreamEvent? {
        switch sse.event {
        case "ping":
            return nil
        case "error":
            let body = try? HTTPTransport.decoder.decode(JSONValue.self, from: Data(sse.data.utf8))
            throw AnthropicError.from(response: response, body: body)
        case "message_start", "message_delta", "message_stop",
             "content_block_start", "content_block_delta", "content_block_stop":
            let data = try injectingType(sse.data, from: sse.event)
            return try HTTPTransport.decoder.decode(RawMessageStreamEvent.self, from: data)
        default:
            return nil
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
