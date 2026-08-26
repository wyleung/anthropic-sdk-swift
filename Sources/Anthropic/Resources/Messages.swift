import Foundation

public struct Messages: Sendable {
    unowned let client: AnthropicClient

    public func create(
        _ params: MessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> Message {
        try await client.transport.send(method: "POST", path: "v1/messages", body: params, options: options)
    }

    public func stream(
        _ params: MessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageStream {
        let (response, sse) = try await client.transport.stream(
            method: "POST", path: "v1/messages", body: try Self.streamingBody(for: params), options: options
        )
        return MessageStream(response: response, sse: sse)
    }

    /// `MessageCreateParams` has no public `stream` field -- it isn't something a `.create()`
    /// caller should ever set by hand -- so this injects it into the already-encoded body, the
    /// same `JSONSerialization`-on-raw-bytes technique `MessagesSSE.injectingType` uses to avoid
    /// `.convertFromSnakeCase` rewriting keys it shouldn't.
    private static func streamingBody(for params: MessageCreateParams) throws -> Data {
        let data = try HTTPTransport.encoder.encode(params)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        object["stream"] = true
        return try JSONSerialization.data(withJSONObject: object)
    }
}
