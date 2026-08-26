public struct CitationCharLocationParam: Encodable, Sendable, Equatable {
    public let type = "char_location"
    public let citedText: String
    public let documentIndex: Int
    public let documentTitle: String?
    public let startCharIndex: Int
    public let endCharIndex: Int

    public init(
        citedText: String,
        documentIndex: Int,
        documentTitle: String? = nil,
        startCharIndex: Int,
        endCharIndex: Int
    ) {
        self.citedText = citedText
        self.documentIndex = documentIndex
        self.documentTitle = documentTitle
        self.startCharIndex = startCharIndex
        self.endCharIndex = endCharIndex
    }
}

public struct CitationPageLocationParam: Encodable, Sendable, Equatable {
    public let type = "page_location"
    public let citedText: String
    public let documentIndex: Int
    public let documentTitle: String?
    public let startPageNumber: Int
    public let endPageNumber: Int

    public init(
        citedText: String,
        documentIndex: Int,
        documentTitle: String? = nil,
        startPageNumber: Int,
        endPageNumber: Int
    ) {
        self.citedText = citedText
        self.documentIndex = documentIndex
        self.documentTitle = documentTitle
        self.startPageNumber = startPageNumber
        self.endPageNumber = endPageNumber
    }
}

public struct CitationContentBlockLocationParam: Encodable, Sendable, Equatable {
    public let type = "content_block_location"
    public let citedText: String
    public let documentIndex: Int
    public let documentTitle: String?
    public let startBlockIndex: Int
    public let endBlockIndex: Int

    public init(
        citedText: String,
        documentIndex: Int,
        documentTitle: String? = nil,
        startBlockIndex: Int,
        endBlockIndex: Int
    ) {
        self.citedText = citedText
        self.documentIndex = documentIndex
        self.documentTitle = documentTitle
        self.startBlockIndex = startBlockIndex
        self.endBlockIndex = endBlockIndex
    }
}

public struct CitationWebSearchResultLocationParam: Encodable, Sendable, Equatable {
    public let type = "web_search_result_location"
    public let citedText: String
    public let encryptedIndex: String
    public let title: String?
    public let url: String

    public init(
        citedText: String,
        encryptedIndex: String,
        title: String? = nil,
        url: String
    ) {
        self.citedText = citedText
        self.encryptedIndex = encryptedIndex
        self.title = title
        self.url = url
    }
}

public struct CitationSearchResultLocationParam: Encodable, Sendable, Equatable {
    public let type = "search_result_location"
    public let citedText: String
    public let source: String
    public let title: String?
    public let startBlockIndex: Int
    public let endBlockIndex: Int
    public let searchResultIndex: Int

    public init(
        citedText: String,
        source: String,
        title: String? = nil,
        startBlockIndex: Int,
        endBlockIndex: Int,
        searchResultIndex: Int
    ) {
        self.citedText = citedText
        self.source = source
        self.title = title
        self.startBlockIndex = startBlockIndex
        self.endBlockIndex = endBlockIndex
        self.searchResultIndex = searchResultIndex
    }
}

public enum TextCitationParam: Sendable, Equatable {
    case charLocation(CitationCharLocationParam)
    case pageLocation(CitationPageLocationParam)
    case contentBlockLocation(CitationContentBlockLocationParam)
    case webSearchResultLocation(CitationWebSearchResultLocationParam)
    case searchResultLocation(CitationSearchResultLocationParam)
}

extension TextCitationParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .charLocation(let value): try value.encode(to: encoder)
        case .pageLocation(let value): try value.encode(to: encoder)
        case .contentBlockLocation(let value): try value.encode(to: encoder)
        case .webSearchResultLocation(let value): try value.encode(to: encoder)
        case .searchResultLocation(let value): try value.encode(to: encoder)
        }
    }
}
