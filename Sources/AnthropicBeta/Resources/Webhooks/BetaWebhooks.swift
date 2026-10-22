import Anthropic
import Foundation

/// Exposed as `client.beta.webhooks`, mirroring the reference SDKs' `client.beta.webhooks.unwrap`
/// call site. Unlike every other Beta resource this holds no `client` reference at all -- `unwrap`
/// makes no HTTP call, so there is nothing for a client to do here. This type exists purely so
/// callers already used to the reference SDKs' shape don't have to reach for a bare static function.
public struct BetaWebhooks: Sendable {
    /// Forwards to `AnthropicWebhooks.unwrap` -- see that function for the full contract.
    /// Parses a webhook payload **without verifying its signature**; prefer `unwrap`. See
    /// `AnthropicWebhooks.parseUnverified`.
    public func parseUnverified(payload: String) throws -> BetaWebhookEvent {
        try AnthropicWebhooks.parseUnverified(payload: payload)
    }

    public func unwrap(
        payload: String,
        headers: [String: String],
        key: String,
        clock: () -> Date = { Date() }
    ) throws -> BetaWebhookEvent {
        try AnthropicWebhooks.unwrap(payload: payload, headers: headers, key: key, clock: clock)
    }
}

extension Beta {
    public var webhooks: BetaWebhooks { BetaWebhooks() }
}
