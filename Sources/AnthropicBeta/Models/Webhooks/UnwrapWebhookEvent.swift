import Anthropic

/// A webhook event envelope: what `AnthropicWebhooks.unwrap` returns once the signature checks out, and what
/// `parseUnverified` returns without checking it. Ported from `types/beta/beta_webhook_event.py`;
/// `unwrap_webhook_event.py` is now just an alias of it (`UnwrapWebhookEvent`, below), which is why this
/// type was once named only `UnwrapWebhookEvent`.
public struct BetaWebhookEvent: Codable, Sendable, Equatable {
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

/// What `unwrap` returns -- upstream's alias for `BetaWebhookEvent`.
public typealias UnwrapWebhookEvent = BetaWebhookEvent
