import Anthropic

/// Failure detail for a Dream whose `status` is `failed`. Ported from `beta_dream_error.py` --
/// `type` is a bare `str` in Python, not a closed set, so it stays a plain `String` here rather
/// than a discriminated-union case.
public struct BetaDreamError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String) {
        self.message = message
        self.type = type
    }
}
