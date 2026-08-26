public struct BashCodeExecutionOutputBlock: Codable, Sendable, Equatable {
    public let type = "bash_code_execution_output"
    public let fileId: String

    private enum CodingKeys: String, CodingKey {
        case type, fileId
    }
}

public struct BashCodeExecutionResultBlock: Codable, Sendable, Equatable {
    public let type = "bash_code_execution_result"
    public let stdout: String
    public let stderr: String
    public let returnCode: Int
    public let content: [BashCodeExecutionOutputBlock]

    private enum CodingKeys: String, CodingKey {
        case type, stdout, stderr, returnCode, content
    }
}

public struct BashCodeExecutionToolResultError: Codable, Sendable, Equatable {
    public let type = "bash_code_execution_tool_result_error"
    public let errorCode: String

    private enum CodingKeys: String, CodingKey {
        case type, errorCode
    }
}

public enum BashCodeExecutionToolResultContent: Sendable, Equatable {
    case result(BashCodeExecutionResultBlock)
    case error(BashCodeExecutionToolResultError)
    case unknown(type: String, raw: JSONValue)
}

extension BashCodeExecutionToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "bash_code_execution_result":
            self = .result(try BashCodeExecutionResultBlock(from: decoder))
        case "bash_code_execution_tool_result_error":
            self = .error(try BashCodeExecutionToolResultError(from: decoder))
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

public struct BashCodeExecutionToolResultBlock: Codable, Sendable, Equatable {
    public let type = "bash_code_execution_tool_result"
    public let toolUseId: String
    public let content: BashCodeExecutionToolResultContent

    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content
    }
}
