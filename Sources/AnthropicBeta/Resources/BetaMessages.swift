import Anthropic

/// Non-streaming only for this slice -- see the slice-1 deviations note for what's deferred
/// (streaming, batches, tool runner).
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
}
