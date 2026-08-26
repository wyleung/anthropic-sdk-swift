public struct TextBlockParam: Encodable, Sendable, Equatable {
    public let type = "text"
    public let text: String
    public let cacheControl: CacheControlEphemeral?
    public let citations: [TextCitationParam]?

    public init(
        text: String,
        cacheControl: CacheControlEphemeral? = nil,
        citations: [TextCitationParam]? = nil
    ) {
        self.text = text
        self.cacheControl = cacheControl
        self.citations = citations
    }
}
