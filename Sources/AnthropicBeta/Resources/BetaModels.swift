import Anthropic

public struct BetaModels: Sendable {
    unowned let client: AnthropicClient

    /// Get a specific model. `modelId` may be a model ID or alias.
    public func retrieve(
        _ modelId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaModelInfo {
        try await client.transport.get(
            path: "v1/models/\(modelId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    /// List available models, most recently released first.
    public func list(
        afterId: String? = nil,
        beforeId: String? = nil,
        limit: Int? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<BetaModelInfo> {
        try await client.transport.get(
            path: "v1/models",
            query: betaQuery.merging(
                ["after_id": afterId, "before_id": beforeId, "limit": limit.map(String.init)]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, base: options)
        )
    }
}
