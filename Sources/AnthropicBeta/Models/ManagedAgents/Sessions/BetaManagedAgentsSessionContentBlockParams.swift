import Anthropic

/// Base64-encoded image data. Ported from `sessions/beta_managed_agents_base64_image_source_param.py`.
/// `mediaType` is a plain `String` (not a closed enum) -- Python types it as `Required[str]`, not a
/// `Literal`, unlike GA's `Base64ImageSourceParam.MediaType`.
public struct BetaManagedAgentsBase64ImageSourceParam: Encodable, Sendable, Equatable {
    public var data: String
    public var mediaType: String
    public var type = "base64"

    public init(data: String, mediaType: String) {
        self.data = data
        self.mediaType = mediaType
    }
}

/// Image referenced by URL. Ported from `sessions/beta_managed_agents_url_image_source_param.py`.
public struct BetaManagedAgentsURLImageSourceParam: Encodable, Sendable, Equatable {
    public var type = "url"
    public var url: String

    public init(url: String) {
        self.url = url
    }
}

/// Image referenced by file ID. Ported from `sessions/beta_managed_agents_file_image_source_param.py`.
public struct BetaManagedAgentsFileImageSourceParam: Encodable, Sendable, Equatable {
    public var fileId: String
    public var type = "file"

    public init(fileId: String) {
        self.fileId = fileId
    }
}

/// Ported from the `Source` union local to `sessions/beta_managed_agents_image_block_param.py`.
/// Request-only (no `.unknown`); each leaf carries its own fixed `type` literal.
public enum BetaManagedAgentsImageSourceParam: Sendable, Equatable {
    case base64(BetaManagedAgentsBase64ImageSourceParam)
    case url(BetaManagedAgentsURLImageSourceParam)
    case file(BetaManagedAgentsFileImageSourceParam)
}

extension BetaManagedAgentsImageSourceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        }
    }
}

/// Image content specified directly as base64 data or as a reference via a URL or file ID. Ported
/// from `sessions/beta_managed_agents_image_block_param.py`.
public struct BetaManagedAgentsImageBlockParam: Encodable, Sendable, Equatable {
    public var source: BetaManagedAgentsImageSourceParam
    public var type = "image"

    public init(source: BetaManagedAgentsImageSourceParam) {
        self.source = source
    }
}

/// Base64-encoded document data. Ported from
/// `sessions/beta_managed_agents_base64_document_source_param.py`. `mediaType` is a plain `String`
/// (not a closed enum) -- Python types it as `Required[str]`.
public struct BetaManagedAgentsBase64DocumentSourceParam: Encodable, Sendable, Equatable {
    public var data: String
    public var mediaType: String
    public var type = "base64"

    public init(data: String, mediaType: String) {
        self.data = data
        self.mediaType = mediaType
    }
}

/// Plain text document content. Ported from
/// `sessions/beta_managed_agents_plain_text_document_source_param.py`. `mediaType` is a fixed
/// `Literal["text/plain"]` in Python, so it's a hardcoded default here (same treatment as `type`).
public struct BetaManagedAgentsPlainTextDocumentSourceParam: Encodable, Sendable, Equatable {
    public var data: String
    public var mediaType = "text/plain"
    public var type = "text"

    public init(data: String) {
        self.data = data
    }
}

/// Document referenced by URL. Ported from `sessions/beta_managed_agents_url_document_source_param.py`.
public struct BetaManagedAgentsURLDocumentSourceParam: Encodable, Sendable, Equatable {
    public var type = "url"
    public var url: String

    public init(url: String) {
        self.url = url
    }
}

/// Document referenced by file ID. Ported from `sessions/beta_managed_agents_file_document_source_param.py`.
public struct BetaManagedAgentsFileDocumentSourceParam: Encodable, Sendable, Equatable {
    public var fileId: String
    public var type = "file"

    public init(fileId: String) {
        self.fileId = fileId
    }
}

/// Ported from the `Source` union local to `sessions/beta_managed_agents_document_block_param.py`.
/// Request-only (no `.unknown`); each leaf carries its own fixed `type` literal.
public enum BetaManagedAgentsDocumentSourceParam: Sendable, Equatable {
    case base64(BetaManagedAgentsBase64DocumentSourceParam)
    case plainText(BetaManagedAgentsPlainTextDocumentSourceParam)
    case url(BetaManagedAgentsURLDocumentSourceParam)
    case file(BetaManagedAgentsFileDocumentSourceParam)
}

extension BetaManagedAgentsDocumentSourceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64(let value): try value.encode(to: encoder)
        case .plainText(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        }
    }
}

/// Document content, either specified directly as base64 data, as text, or as a reference via a URL
/// or file ID. Ported from `sessions/beta_managed_agents_document_block_param.py`.
public struct BetaManagedAgentsDocumentBlockParam: Encodable, Sendable, Equatable {
    public var source: BetaManagedAgentsDocumentSourceParam
    public var type = "document"
    public var context: String?
    public var title: String?

    public init(source: BetaManagedAgentsDocumentSourceParam, context: String? = nil, title: String? = nil) {
        self.source = source
        self.context = context
        self.title = title
    }
}

/// Regular text content. Ported from `sessions/beta_managed_agents_text_block_param.py`.
public struct BetaManagedAgentsTextBlockParam: Encodable, Sendable, Equatable {
    public var text: String
    public var type = "text"

    public init(text: String) {
        self.text = text
    }
}

/// Placeholder for content withheld by Anthropic model policy. Ported from
/// `sessions/beta_managed_agents_redacted_block_param.py`.
public struct BetaManagedAgentsRedactedBlockParam: Encodable, Sendable, Equatable {
    public var type = "redacted"

    public init() {}
}

/// Ported from the `Content` union local to `sessions/beta_managed_agents_user_message_event_params.py`.
/// Request-only (no `.unknown`); each leaf carries its own fixed `type` literal.
public enum BetaManagedAgentsUserMessageContentParam: Sendable, Equatable {
    case text(BetaManagedAgentsTextBlockParam)
    case image(BetaManagedAgentsImageBlockParam)
    case document(BetaManagedAgentsDocumentBlockParam)
    case redacted(BetaManagedAgentsRedactedBlockParam)
}

extension BetaManagedAgentsUserMessageContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .document(let value): try value.encode(to: encoder)
        case .redacted(let value): try value.encode(to: encoder)
        }
    }
}
