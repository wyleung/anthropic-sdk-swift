import Anthropic

/// The decoded, signature-verified result of `AnthropicWebhooks.unwrap`/`client.beta.webhooks.unwrap`.
/// Mirrors `types/beta/unwrap_webhook_event.py` -- the real Python source type name; `api.md`'s
/// `BetaWebhookEvent` doesn't exist in source (TypeScript names both, Python only this one), the
/// same class of doc-vs-source naming gap as `SkillSource` in Phase 6.
public struct UnwrapWebhookEvent: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let data: BetaWebhookEventData
    public let type: String

    public init(id: String, createdAt: String, data: BetaWebhookEventData, type: String = "event") {
        self.id = id
        self.createdAt = createdAt
        self.data = data
        self.type = type
    }
}
