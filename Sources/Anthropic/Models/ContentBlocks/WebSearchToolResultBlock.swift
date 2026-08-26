public struct WebSearchResultBlock: Codable, Sendable, Equatable {
    public let type = "web_search_result"
    public let title: String
    public let url: String
    public let encryptedContent: String
    public let pageAge: String?

    private enum CodingKeys: String, CodingKey {
        case type, title, url, encryptedContent, pageAge
    }
}

public struct WebSearchToolResultError: Codable, Sendable, Equatable {
    public let type = "web_search_tool_result_error"
    public let errorCode: String

    private enum CodingKeys: String, CodingKey {
        case type, errorCode
    }
}

/// `content` is either an array of results or an error object — no shared `type` field to
/// discriminate on (`web_search_tool_result_block_content.py` is a plain, untagged `Union`).
public enum WebSearchToolResultContent: Sendable, Equatable {
    case results([WebSearchResultBlock])
    case error(WebSearchToolResultError)
    case unknown(JSONValue)
}

extension WebSearchToolResultContent: Codable {
    public init(from decoder: Decoder) throws {
        if let results = try? [WebSearchResultBlock](from: decoder) {
            self = .results(results)
        } else if let error = try? WebSearchToolResultError(from: decoder) {
            self = .error(error)
        } else {
            self = .unknown(try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .results(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .unknown(let raw): try raw.encode(to: encoder)
        }
    }
}

public struct WebSearchToolResultBlock: Codable, Sendable, Equatable {
    public let type = "web_search_tool_result"
    public let toolUseId: String
    public let content: WebSearchToolResultContent
    public let caller: Caller?

    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content, caller
    }
}
