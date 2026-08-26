public enum ToolResultContentBlockParam: Sendable, Equatable {
    case text(TextBlockParam)
    case image(ImageBlockParam)
    case searchResult(SearchResultBlockParam)
    case document(DocumentBlockParam)
    case toolReference(ToolReferenceBlockParam)
    case browserState(BrowserStateBlockParam)
}

extension ToolResultContentBlockParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .searchResult(let value): try value.encode(to: encoder)
        case .document(let value): try value.encode(to: encoder)
        case .toolReference(let value): try value.encode(to: encoder)
        case .browserState(let value): try value.encode(to: encoder)
        }
    }
}

public enum ToolResultContentParam: Sendable, Equatable {
    case text(String)
    case blocks([ToolResultContentBlockParam])
}

extension ToolResultContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .blocks(let value): try container.encode(value)
        }
    }
}

public struct ToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "tool_result"
    public let toolUseId: String
    public let cacheControl: CacheControlEphemeral?
    public let content: ToolResultContentParam?
    public let isError: Bool?
    public let toolsetName: String?

    public init(
        toolUseId: String,
        content: ToolResultContentParam? = nil,
        isError: Bool? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        toolsetName: String? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
        self.cacheControl = cacheControl
        self.toolsetName = toolsetName
    }
}
