import Foundation
import Anthropic

public struct BetaMessages: Sendable {
    unowned let client: AnthropicClient

    public func create(
        _ params: BetaMessageCreateParams,
        betas: [String] = [],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaMessage {
        try await client.transport.send(
            method: "POST",
            path: "v1/messages",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, userProfileId: userProfileId, base: options)
        )
    }

    public func stream(
        _ params: BetaMessageCreateParams,
        betas: [String] = [],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaMessageStream {
        let (response, sse) = try await client.transport.stream(
            method: "POST",
            path: "v1/messages",
            query: betaQuery,
            body: try Self.streamingBody(for: params),
            options: betaRequestOptions(betas: betas, userProfileId: userProfileId, base: options)
        )
        return BetaMessageStream(response: response, sse: sse)
    }

    /// Convenience entry point mirroring the reference SDKs' `client.beta.messages.tool_runner(...)`
    /// -- unlike GA, which has no analogous `messages.toolRunner(...)` and expects callers to
    /// construct `ToolRunner(...)` directly, this is added for Beta since the underlying product
    /// surface (Python/TS) always exposes it as a `messages`-namespaced factory.
    public func toolRunner(
        _ params: BetaMessageCreateParams,
        tools: [AnyAnthropicTool],
        betas: [String] = [],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions(),
        maxIterations: Int? = nil
    ) -> BetaToolRunner {
        BetaToolRunner(
            client: client,
            params: params,
            tools: tools,
            betas: betas,
            userProfileId: userProfileId,
            options: options,
            maxIterations: maxIterations
        )
    }

    /// `BetaMessageCreateParams` has no public `stream` field -- see GA's `Messages.streamingBody`
    /// for why this injects it into the already-encoded body rather than adding the field.
    private static func streamingBody(for params: BetaMessageCreateParams) throws -> Data {
        let data = try HTTPTransport.encoder.encode(params)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        object["stream"] = true
        return try JSONSerialization.data(withJSONObject: object)
    }
}
