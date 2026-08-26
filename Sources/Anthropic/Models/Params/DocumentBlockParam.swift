public struct Base64PDFSourceParam: Encodable, Sendable, Equatable {
    public let type = "base64"
    public let mediaType = "application/pdf"
    public let data: String

    public init(data: String) {
        self.data = data
    }
}

public struct PlainTextSourceParam: Encodable, Sendable, Equatable {
    public let type = "text"
    public let mediaType = "text/plain"
    public let data: String

    public init(data: String) {
        self.data = data
    }
}

public enum ContentBlockSourceContentBlockParam: Sendable, Equatable {
    case text(TextBlockParam)
    case image(ImageBlockParam)
}

extension ContentBlockSourceContentBlockParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        }
    }
}

public enum ContentBlockSourceContent: Sendable, Equatable {
    case text(String)
    case blocks([ContentBlockSourceContentBlockParam])
}

extension ContentBlockSourceContent: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .blocks(let value): try container.encode(value)
        }
    }
}

public struct ContentBlockSourceParam: Encodable, Sendable, Equatable {
    public let type = "content"
    public let content: ContentBlockSourceContent

    public init(content: ContentBlockSourceContent) {
        self.content = content
    }
}

public struct URLPDFSourceParam: Encodable, Sendable, Equatable {
    public let type = "url"
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

public struct FileDocumentSourceParam: Encodable, Sendable, Equatable {
    public let type = "file"
    public let fileId: String

    public init(fileId: String) {
        self.fileId = fileId
    }
}

public enum DocumentSourceParam: Sendable, Equatable {
    case base64PDF(Base64PDFSourceParam)
    case plainText(PlainTextSourceParam)
    case content(ContentBlockSourceParam)
    case url(URLPDFSourceParam)
    case file(FileDocumentSourceParam)
}

extension DocumentSourceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64PDF(let value): try value.encode(to: encoder)
        case .plainText(let value): try value.encode(to: encoder)
        case .content(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        }
    }
}

public struct CitationsConfigParam: Encodable, Sendable, Equatable {
    public let enabled: Bool?

    public init(enabled: Bool? = nil) {
        self.enabled = enabled
    }
}

public struct DocumentBlockParam: Encodable, Sendable, Equatable {
    public let type = "document"
    public let source: DocumentSourceParam
    public let cacheControl: CacheControlEphemeral?
    public let citations: CitationsConfigParam?
    public let context: String?
    public let title: String?

    public init(
        source: DocumentSourceParam,
        cacheControl: CacheControlEphemeral? = nil,
        citations: CitationsConfigParam? = nil,
        context: String? = nil,
        title: String? = nil
    ) {
        self.source = source
        self.cacheControl = cacheControl
        self.citations = citations
        self.context = context
        self.title = title
    }
}
