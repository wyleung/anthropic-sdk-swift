/// Ported from `types/beta/beta_fallback_info.py` and `beta_fallback_info_param.py`. Both are the
/// single-field shape `{model}` -- Python declares a response `BaseModel` and a request `TypedDict`
/// with identical fields, so one `Codable` Swift type serves both directions, matching GA's
/// convention of plain `String` for model identifiers (`Model`/`ModelParam` are Python typing
/// aliases over `str`, not distinct wire shapes).
public struct BetaFallbackInfo: Codable, Sendable, Equatable {
    public let model: String

    public init(model: String) {
        self.model = model
    }
}
