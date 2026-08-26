/// Ported from `types/model_info.py`. `createdAt` stays a `String` rather than `Date`, matching
/// `Container.expiresAt` -- this port's `HTTPTransport.decoder` has no ISO-8601 date strategy set.
public struct ModelInfo: Codable, Sendable, Equatable {
    public let id: String
    public let capabilities: ModelCapabilities?
    public let createdAt: String
    public let displayName: String
    public let maxInputTokens: Int?
    public let maxTokens: Int?
    public let type: String
}
