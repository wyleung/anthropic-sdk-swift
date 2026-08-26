import Foundation
import Anthropic

/// The Beta analogue of GA's `MessagesSSE`: translates decoded SSE messages into
/// `BetaRawMessageStreamEvent`s for the Beta Messages API. Same event vocabulary and same
/// `ping`/`error`/forward-compatible-drop handling as GA -- duplicated rather than reused since
/// GA's `MessagesSSE` is `internal` to the `Anthropic` module and decodes GA's own
/// `RawMessageStreamEvent`.
enum BetaMessagesSSE {
    static func translate(_ sse: ServerSentEvent, response: HTTPURLResponse) throws -> BetaRawMessageStreamEvent? {
        switch sse.event {
        case "ping":
            return nil
        case "error":
            let body = try? HTTPTransport.decoder.decode(JSONValue.self, from: Data(sse.data.utf8))
            throw AnthropicError.from(response: response, body: body)
        case "message_start", "message_delta", "message_stop",
             "content_block_start", "content_block_delta", "content_block_stop":
            let data = try injectingType(sse.data, from: sse.event)
            return try HTTPTransport.decoder.decode(BetaRawMessageStreamEvent.self, from: data)
        default:
            return nil
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
