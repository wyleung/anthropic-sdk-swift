/// Ported from `types/model_info.py`. `createdAt` stays a `String` rather than `Date`, matching
/// `Container.expiresAt` -- this port's `HTTPTransport.decoder` has no ISO-8601 date strategy set.
///
/// `lifecycle`, `line`, `deprecatedAt` and `retiresAt` are all optional here even though Python marks
/// `lifecycle` required: they postdate this port, and a response (or a proxy) that omits one must not
/// fail decoding of the entire `models.list` page. Timestamps are RFC 3339 strings.
public struct ModelInfo: Codable, Sendable, Equatable {
    public let id: String
    public let capabilities: ModelCapabilities?
    public let createdAt: String
    /// When the model was most recently deprecated. Set for `deprecated` and `retired` models,
    /// `nil` while `active`.
    public let deprecatedAt: String?
    public let displayName: String
    /// The model's current lifecycle stage; this, not `retiresAt`, is the retirement signal.
    public let lifecycle: ModelLifecycle?
    /// The model line this model belongs to. `nil` when it belongs to none -- don't infer a line
    /// from the `id`.
    public let line: ModelLine?
    public let maxInputTokens: Int?
    public let maxTokens: Int?
    /// The currently scheduled retirement date, which can be revised until retirement occurs. `nil`
    /// while `active` or while none is scheduled. A past date on a `deprecated` model means
    /// retirement is overdue, not that it has occurred.
    public let retiresAt: String?
    public let type: String
}
