public struct CitationCharLocation: Codable, Sendable, Equatable {
    public let type = "char_location"
    public let citedText: String
    public let documentIndex: Int
    public let documentTitle: String?
    public let startCharIndex: Int
    public let endCharIndex: Int
    public let fileId: String?

    private enum CodingKeys: String, CodingKey {
        case type, citedText, documentIndex, documentTitle, startCharIndex, endCharIndex, fileId
    }
}

public struct CitationPageLocation: Codable, Sendable, Equatable {
    public let type = "page_location"
    public let citedText: String
    public let documentIndex: Int
    public let documentTitle: String?
    public let startPageNumber: Int
    public let endPageNumber: Int
    public let fileId: String?

    private enum CodingKeys: String, CodingKey {
        case type, citedText, documentIndex, documentTitle, startPageNumber, endPageNumber, fileId
    }
}

public struct CitationContentBlockLocation: Codable, Sendable, Equatable {
    public let type = "content_block_location"
    public let citedText: String
    public let documentIndex: Int
    public let documentTitle: String?
    public let startBlockIndex: Int
    public let endBlockIndex: Int
    public let fileId: String?

    private enum CodingKeys: String, CodingKey {
        case type, citedText, documentIndex, documentTitle, startBlockIndex, endBlockIndex, fileId
    }
}

public struct CitationWebSearchResultLocation: Codable, Sendable, Equatable {
    public let type = "web_search_result_location"
    public let citedText: String
    public let encryptedIndex: String
    public let title: String?
    public let url: String

    private enum CodingKeys: String, CodingKey {
        case type, citedText, encryptedIndex, title, url
    }
}

public struct CitationSearchResultLocation: Codable, Sendable, Equatable {
    public let type = "search_result_location"
    public let citedText: String
    public let source: String
    public let title: String?
    public let startBlockIndex: Int
    public let endBlockIndex: Int
    public let searchResultIndex: Int

    private enum CodingKeys: String, CodingKey {
        case type, citedText, source, title, startBlockIndex, endBlockIndex, searchResultIndex
    }
}

/// Ported from `types/text_citation.py`'s 5-case discriminated union.
public enum TextCitation: Sendable, Equatable {
    case charLocation(CitationCharLocation)
    case pageLocation(CitationPageLocation)
    case contentBlockLocation(CitationContentBlockLocation)
    case webSearchResultLocation(CitationWebSearchResultLocation)
    case searchResultLocation(CitationSearchResultLocation)
    case unknown(type: String, raw: JSONValue)
}

extension TextCitation: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "char_location":
            self = .charLocation(try CitationCharLocation(from: decoder))
        case "page_location":
            self = .pageLocation(try CitationPageLocation(from: decoder))
        case "content_block_location":
            self = .contentBlockLocation(try CitationContentBlockLocation(from: decoder))
        case "web_search_result_location":
            self = .webSearchResultLocation(try CitationWebSearchResultLocation(from: decoder))
        case "search_result_location":
            self = .searchResultLocation(try CitationSearchResultLocation(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .charLocation(let value): try value.encode(to: encoder)
        case .pageLocation(let value): try value.encode(to: encoder)
        case .contentBlockLocation(let value): try value.encode(to: encoder)
        case .webSearchResultLocation(let value): try value.encode(to: encoder)
        case .searchResultLocation(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
