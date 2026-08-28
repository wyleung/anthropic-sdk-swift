import Foundation

public struct Messages: Sendable {
    unowned let client: AnthropicClient

    /// `userProfileId` is sent as the `anthropic-user-profile-id` header (not a body field) to
    /// attribute this request to that user profile; requires the `user-profiles` beta header to be
    /// set separately.
    public func create(
        _ params: MessageCreateParams,
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> Message {
        try await client.transport.send(
            method: "POST", path: "v1/messages", body: params,
            options: Self.mergedOptions(userProfileId: userProfileId, base: options)
        )
    }

    /// `userProfileId` is sent as the `anthropic-user-profile-id` header (not a body field) to
    /// attribute this request to that user profile; requires the `user-profiles` beta header to be
    /// set separately.
    public func stream(
        _ params: MessageCreateParams,
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageStream {
        let (response, sse) = try await client.transport.stream(
            method: "POST", path: "v1/messages", body: try Self.streamingBody(for: params),
            options: Self.mergedOptions(userProfileId: userProfileId, base: options)
        )
        return MessageStream(response: response, sse: sse)
    }

    private static func mergedOptions(userProfileId: String?, base options: RequestOptions) -> RequestOptions {
        var headers: [String: String?] = [:]
        if let userProfileId {
            headers["anthropic-user-profile-id"] = userProfileId
        }
        headers.merge(options.headers) { _, new in new }
        var mergedOptions = options
        mergedOptions.headers = headers
        return mergedOptions
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
