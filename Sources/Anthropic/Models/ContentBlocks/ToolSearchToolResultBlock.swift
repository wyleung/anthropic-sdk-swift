public struct ToolReferenceBlock: Codable, Sendable, Equatable {
    public let type = "tool_reference"
    public let toolName: String

    private enum CodingKeys: String, CodingKey {
        case type, toolName
    }
}

public struct ToolSearchToolSearchResultBlock: Codable, Sendable, Equatable {
    public let type = "tool_search_tool_search_result"
    public let toolReferences: [ToolReferenceBlock]

    private enum CodingKeys: String, CodingKey {
        case type, toolReferences
    }
}

public struct ToolSearchToolResultError: Codable, Sendable, Equatable {
    public let type = "tool_search_tool_result_error"
    public let errorCode: String
    public let errorMessage: String?

    private enum CodingKeys: String, CodingKey {
        case type, errorCode, errorMessage
    }
}

public enum ToolSearchToolResultContent: Sendable, Equatable {
    case result(ToolSearchToolSearchResultBlock)
    case error(ToolSearchToolResultError)
    case unknown(type: String, raw: JSONValue)
}

extension ToolSearchToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "tool_search_tool_search_result":
            self = .result(try ToolSearchToolSearchResultBlock(from: decoder))
        case "tool_search_tool_result_error":
            self = .error(try ToolSearchToolResultError(from: decoder))
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

public struct ToolSearchToolResultBlock: Codable, Sendable, Equatable {
    public let type = "tool_search_tool_result"
    public let toolUseId: String
    public let content: ToolSearchToolResultContent

    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content
    }
}
