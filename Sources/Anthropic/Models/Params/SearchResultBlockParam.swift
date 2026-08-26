public struct SearchResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "search_result"
    public let content: [TextBlockParam]
    public let source: String
    public let title: String
    public let cacheControl: CacheControlEphemeral?
    public let citations: CitationsConfigParam?

    public init(
        content: [TextBlockParam],
        source: String,
        title: String,
        cacheControl: CacheControlEphemeral? = nil,
        citations: CitationsConfigParam? = nil
    ) {
        self.content = content
        self.source = source
        self.title = title
        self.cacheControl = cacheControl
        self.citations = citations
    }
}
