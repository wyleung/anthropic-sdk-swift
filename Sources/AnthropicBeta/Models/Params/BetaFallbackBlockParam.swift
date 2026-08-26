import Anthropic

/// Ported from `types/beta/beta_fallback_block_param.py`. Echoes a response `fallback` block back
/// verbatim in `messages[].content`. Unlike the response side, `from` is optional here (Python's
/// TypedDict doesn't mark it `Required`) and `trigger` is an untyped `object` the server accepts and
/// ignores -- modeled as `JSONValue?` rather than `BetaFallbackRefusalTrigger?` since "any object or
/// null" is looser than that type.
public struct BetaFallbackBlockParam: Encodable, Sendable, Equatable {
    public let to: BetaFallbackInfo
    public let type = "fallback"
    public let from: BetaFallbackInfo?
    public let trigger: JSONValue?

    public init(to: BetaFallbackInfo, from: BetaFallbackInfo? = nil, trigger: JSONValue? = nil) {
        self.to = to
        self.from = from
        self.trigger = trigger
    }

    private enum CodingKeys: String, CodingKey {
        case to, type, from, trigger
    }
}
