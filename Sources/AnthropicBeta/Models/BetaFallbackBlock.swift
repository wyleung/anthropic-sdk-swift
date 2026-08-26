/// Ported from `types/beta/beta_fallback_block.py`. Marks the point in `content` where one model's
/// output gives way to the next during a fallback hop; arrives via plain `content_block_start`/`stop`
/// only (no delta). Python's field is aliased `from_` -> JSON key `"from"`; Swift can use the real
/// keyword via backticks instead, so no alias trick is needed.
public struct BetaFallbackBlock: Codable, Sendable, Equatable {
    public let `from`: BetaFallbackInfo
    public let to: BetaFallbackInfo
    public let trigger: BetaFallbackRefusalTrigger
    public let type = "fallback"

    public init(from: BetaFallbackInfo, to: BetaFallbackInfo, trigger: BetaFallbackRefusalTrigger) {
        self.from = from
        self.to = to
        self.trigger = trigger
    }

    private enum CodingKeys: String, CodingKey {
        case from, to, trigger, type
    }
}
