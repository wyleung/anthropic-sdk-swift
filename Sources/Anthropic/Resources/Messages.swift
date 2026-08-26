public struct Messages: Sendable {
    unowned let client: AnthropicClient

    public func create(
        _ params: MessageCreateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> Message {
        try await client.transport.send(method: "POST", path: "v1/messages", body: params, options: options)
    }
}
