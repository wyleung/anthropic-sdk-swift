public struct TextBlock: Codable, Sendable, Equatable {
    public let type = "text"
    public let text: String
    public let citations: [TextCitation]?

    private enum CodingKeys: String, CodingKey {
        case type, text, citations
    }

    public init(text: String, citations: [TextCitation]? = nil) {
        self.text = text
        self.citations = citations
    }
}
