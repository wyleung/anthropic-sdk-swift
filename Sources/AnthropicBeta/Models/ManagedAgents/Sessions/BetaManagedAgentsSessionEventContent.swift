import Anthropic

/// Response-side content blocks carried by session events. Field-identical to the request-side
/// `...Param` types in `BetaManagedAgentsSessionContentBlockParams.swift`, but these are distinct
/// `Decodable` Python classes (e.g. `BetaManagedAgentsTextBlock` vs `BetaManagedAgentsTextBlockParam`)
/// so this port mirrors that with its own set of response-only types, dropping the `Param` suffix.

/// Regular text content. Ported from `sessions/beta_managed_agents_text_block.py`.
public struct BetaManagedAgentsTextBlock: Codable, Sendable, Equatable {
    public let text: String
    public let type: String

    public init(text: String, type: String = "text") {
        self.text = text
        self.type = type
    }
}

/// Base64-encoded image data. Ported from `sessions/beta_managed_agents_base64_image_source.py`.
/// `mediaType` is a plain `String` (not a closed enum), matching the request-side param type.
public struct BetaManagedAgentsBase64ImageSource: Codable, Sendable, Equatable {
    public let data: String
    public let mediaType: String
    public let type: String

    public init(data: String, mediaType: String, type: String = "base64") {
        self.data = data
        self.mediaType = mediaType
        self.type = type
    }
}

/// Image referenced by URL. Ported from `sessions/beta_managed_agents_url_image_source.py`.
public struct BetaManagedAgentsURLImageSource: Codable, Sendable, Equatable {
    public let type: String
    public let url: String

    public init(type: String = "url", url: String) {
        self.type = type
        self.url = url
    }
}

/// Image referenced by file ID. Ported from `sessions/beta_managed_agents_file_image_source.py`.
public struct BetaManagedAgentsFileImageSource: Codable, Sendable, Equatable {
    public let fileId: String
    public let type: String

    public init(fileId: String, type: String = "file") {
        self.fileId = fileId
        self.type = type
    }
}

/// Ported from the `Source` union local to `sessions/beta_managed_agents_image_block.py`,
/// discriminated on `type`.
public enum BetaManagedAgentsImageSource: Sendable, Equatable {
    case base64(BetaManagedAgentsBase64ImageSource)
    case url(BetaManagedAgentsURLImageSource)
    case file(BetaManagedAgentsFileImageSource)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsImageSource: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "base64": self = .base64(try BetaManagedAgentsBase64ImageSource(from: decoder))
        case "url": self = .url(try BetaManagedAgentsURLImageSource(from: decoder))
        case "file": self = .file(try BetaManagedAgentsFileImageSource(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Image content specified directly as base64 data or as a reference via a URL or file ID. Ported
/// from `sessions/beta_managed_agents_image_block.py`.
public struct BetaManagedAgentsImageBlock: Codable, Sendable, Equatable {
    public let source: BetaManagedAgentsImageSource
    public let type: String

    public init(source: BetaManagedAgentsImageSource, type: String = "image") {
        self.source = source
        self.type = type
    }
}

/// Base64-encoded document data. Ported from `sessions/beta_managed_agents_base64_document_source.py`.
public struct BetaManagedAgentsBase64DocumentSource: Codable, Sendable, Equatable {
    public let data: String
    public let mediaType: String
    public let type: String

    public init(data: String, mediaType: String, type: String = "base64") {
        self.data = data
        self.mediaType = mediaType
        self.type = type
    }
}

/// Plain text document content. Ported from
/// `sessions/beta_managed_agents_plain_text_document_source.py`.
public struct BetaManagedAgentsPlainTextDocumentSource: Codable, Sendable, Equatable {
    public let data: String
    public let mediaType: String
    public let type: String

    public init(data: String, mediaType: String = "text/plain", type: String = "text") {
        self.data = data
        self.mediaType = mediaType
        self.type = type
    }
}

/// Document referenced by URL. Ported from `sessions/beta_managed_agents_url_document_source.py`.
public struct BetaManagedAgentsURLDocumentSource: Codable, Sendable, Equatable {
    public let type: String
    public let url: String

    public init(type: String = "url", url: String) {
        self.type = type
        self.url = url
    }
}

/// Document referenced by file ID. Ported from
/// `sessions/beta_managed_agents_file_document_source.py`.
public struct BetaManagedAgentsFileDocumentSource: Codable, Sendable, Equatable {
    public let fileId: String
    public let type: String

    public init(fileId: String, type: String = "file") {
        self.fileId = fileId
        self.type = type
    }
}

/// Ported from the `Source` union local to `sessions/beta_managed_agents_document_block.py`,
/// discriminated on `type`.
public enum BetaManagedAgentsDocumentSource: Sendable, Equatable {
    case base64(BetaManagedAgentsBase64DocumentSource)
    case plainText(BetaManagedAgentsPlainTextDocumentSource)
    case url(BetaManagedAgentsURLDocumentSource)
    case file(BetaManagedAgentsFileDocumentSource)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsDocumentSource: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "base64": self = .base64(try BetaManagedAgentsBase64DocumentSource(from: decoder))
        case "text": self = .plainText(try BetaManagedAgentsPlainTextDocumentSource(from: decoder))
        case "url": self = .url(try BetaManagedAgentsURLDocumentSource(from: decoder))
        case "file": self = .file(try BetaManagedAgentsFileDocumentSource(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64(let value): try value.encode(to: encoder)
        case .plainText(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Document content, either specified directly as base64 data, as text, or as a reference via a
/// URL or file ID. Ported from `sessions/beta_managed_agents_document_block.py`.
public struct BetaManagedAgentsDocumentBlock: Codable, Sendable, Equatable {
    public let source: BetaManagedAgentsDocumentSource
    public let type: String
    public let context: String?
    public let title: String?

    public init(
        source: BetaManagedAgentsDocumentSource, type: String = "document", context: String? = nil,
        title: String? = nil
    ) {
        self.source = source
        self.type = type
        self.context = context
        self.title = title
    }
}

/// Placeholder for content withheld by Anthropic model policy. Ported from
/// `sessions/beta_managed_agents_redacted_block.py`.
public struct BetaManagedAgentsRedactedBlock: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "redacted") {
        self.type = type
    }
}

/// Citation settings for a search result. Ported from
/// `sessions/beta_managed_agents_search_result_citations.py`.
public struct BetaManagedAgentsSearchResultCitations: Codable, Sendable, Equatable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

/// Text content within a search result. Ported from
/// `sessions/beta_managed_agents_search_result_content.py`.
public struct BetaManagedAgentsSearchResultContent: Codable, Sendable, Equatable {
    public let text: String
    public let type: String

    public init(text: String, type: String = "text") {
        self.text = text
        self.type = type
    }
}

/// A block containing a web search result. Ported from
/// `sessions/beta_managed_agents_search_result_block.py`.
public struct BetaManagedAgentsSearchResultBlock: Codable, Sendable, Equatable {
    public let citations: BetaManagedAgentsSearchResultCitations
    public let content: [BetaManagedAgentsSearchResultContent]
    public let source: String
    public let title: String
    public let type: String

    public init(
        citations: BetaManagedAgentsSearchResultCitations, content: [BetaManagedAgentsSearchResultContent],
        source: String, title: String, type: String = "search_result"
    ) {
        self.citations = citations
        self.content = content
        self.source = source
        self.title = title
        self.type = type
    }
}

/// Ported from the `Content` union shared by `user.message`, `agent.thread_message_received`, and
/// `agent.thread_message_sent` (byte-identical `Union[Text, Image, Document, Redacted]` in each of
/// their Python source files). Response-only (no encode path needed beyond round-tripping), with
/// `.unknown` for forward compatibility.
public enum BetaManagedAgentsSessionMessageContent: Sendable, Equatable {
    case text(BetaManagedAgentsTextBlock)
    case image(BetaManagedAgentsImageBlock)
    case document(BetaManagedAgentsDocumentBlock)
    case redacted(BetaManagedAgentsRedactedBlock)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionMessageContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "text": self = .text(try BetaManagedAgentsTextBlock(from: decoder))
        case "image": self = .image(try BetaManagedAgentsImageBlock(from: decoder))
        case "document": self = .document(try BetaManagedAgentsDocumentBlock(from: decoder))
        case "redacted": self = .redacted(try BetaManagedAgentsRedactedBlock(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .document(let value): try value.encode(to: encoder)
        case .redacted(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from the `Content` union local to `sessions/beta_managed_agents_agent_message_event.py`
/// -- `Union[Text, Redacted]` only (agent responses carry no image/document content).
public enum BetaManagedAgentsAgentMessageContent: Sendable, Equatable {
    case text(BetaManagedAgentsTextBlock)
    case redacted(BetaManagedAgentsRedactedBlock)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsAgentMessageContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "text": self = .text(try BetaManagedAgentsTextBlock(from: decoder))
        case "redacted": self = .redacted(try BetaManagedAgentsRedactedBlock(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .redacted(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from the `Content` union shared by `user.custom_tool_result`, `user.tool_result`,
/// `agent.mcp_tool_result`, and `agent.tool_result` (byte-identical
/// `Union[Text, Image, Document, SearchResult]` in each of their Python source files).
public enum BetaManagedAgentsToolResultContent: Sendable, Equatable {
    case text(BetaManagedAgentsTextBlock)
    case image(BetaManagedAgentsImageBlock)
    case document(BetaManagedAgentsDocumentBlock)
    case searchResult(BetaManagedAgentsSearchResultBlock)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "text": self = .text(try BetaManagedAgentsTextBlock(from: decoder))
        case "image": self = .image(try BetaManagedAgentsImageBlock(from: decoder))
        case "document": self = .document(try BetaManagedAgentsDocumentBlock(from: decoder))
        case "search_result": self = .searchResult(try BetaManagedAgentsSearchResultBlock(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .document(let value): try value.encode(to: encoder)
        case .searchResult(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
