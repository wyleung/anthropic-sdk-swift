import Foundation

public struct Models: Sendable {
    unowned let client: AnthropicClient

    /// Get a specific model. `modelId` may be a model ID or alias.
    public func retrieve(
        _ modelId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> ModelInfo {
        try await client.transport.get(path: "v1/models/\(modelId)", options: options)
    }

    /// List available models, most recently released first.
    public func list(
        afterId: String? = nil,
        beforeId: String? = nil,
        limit: Int? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<ModelInfo> {
        try await client.transport.get(
            path: "v1/models",
            query: [
                "after_id": afterId,
                "before_id": beforeId,
                "limit": limit.map(String.init),
            ],
            options: options
        )
    }
}
