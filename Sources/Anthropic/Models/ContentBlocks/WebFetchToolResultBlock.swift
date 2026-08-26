public struct CitationsConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
}

public struct Base64PDFSource: Codable, Sendable, Equatable {
    public let type = "base64"
    public let mediaType = "application/pdf"
    public let data: String

    private enum CodingKeys: String, CodingKey {
        case type, mediaType, data
    }
}

public struct PlainTextSource: Codable, Sendable, Equatable {
    public let type = "text"
    public let mediaType = "text/plain"
    public let data: String

    private enum CodingKeys: String, CodingKey {
        case type, mediaType, data
    }
}

/// The document embedded in a `WebFetchBlock`. Ported from `document_block.py` — narrower than
/// the request-side `DocumentBlockParam`: only base64/plain-text sources, no URL/file/content variants.
public enum DocumentSource: Sendable, Equatable {
    case base64PDF(Base64PDFSource)
    case plainText(PlainTextSource)
    case unknown(type: String, raw: JSONValue)
}

extension DocumentSource: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "base64":
            self = .base64PDF(try Base64PDFSource(from: decoder))
        case "text":
            self = .plainText(try PlainTextSource(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64PDF(let value): try value.encode(to: encoder)
        case .plainText(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

public struct DocumentBlock: Codable, Sendable, Equatable {
    public let type = "document"
    public let source: DocumentSource
    public let title: String?
    public let citations: CitationsConfig?

    private enum CodingKeys: String, CodingKey {
        case type, source, title, citations
    }
}

public struct WebFetchBlock: Codable, Sendable, Equatable {
    public let type = "web_fetch_result"
    public let url: String
    public let content: DocumentBlock
    public let retrievedAt: String?

    private enum CodingKeys: String, CodingKey {
        case type, url, content, retrievedAt
    }
}

public struct WebFetchToolResultErrorBlock: Codable, Sendable, Equatable {
    public let type = "web_fetch_tool_result_error"
    public let errorCode: String

    private enum CodingKeys: String, CodingKey {
        case type, errorCode
    }
}

public enum WebFetchToolResultContent: Sendable, Equatable {
    case result(WebFetchBlock)
    case error(WebFetchToolResultErrorBlock)
    case unknown(type: String, raw: JSONValue)
}

extension WebFetchToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "web_fetch_result":
            self = .result(try WebFetchBlock(from: decoder))
        case "web_fetch_tool_result_error":
            self = .error(try WebFetchToolResultErrorBlock(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .result(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

public struct WebFetchToolResultBlock: Codable, Sendable, Equatable {
    public let type = "web_fetch_tool_result"
    public let toolUseId: String
    public let content: WebFetchToolResultContent
    public let caller: Caller?

    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content, caller
    }
}
