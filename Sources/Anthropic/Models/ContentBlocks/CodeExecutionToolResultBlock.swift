public struct CodeExecutionOutputBlock: Codable, Sendable, Equatable {
    public let type = "code_execution_output"
    public let fileId: String

    private enum CodingKeys: String, CodingKey {
        case type, fileId
    }
}

public struct CodeExecutionResultBlock: Codable, Sendable, Equatable {
    public let type = "code_execution_result"
    public let stdout: String
    public let stderr: String
    public let returnCode: Int
    public let content: [CodeExecutionOutputBlock]

    private enum CodingKeys: String, CodingKey {
        case type, stdout, stderr, returnCode, content
    }
}

public struct EncryptedCodeExecutionResultBlock: Codable, Sendable, Equatable {
    public let type = "encrypted_code_execution_result"
    public let encryptedStdout: String
    public let stderr: String
    public let returnCode: Int
    public let content: [CodeExecutionOutputBlock]

    private enum CodingKeys: String, CodingKey {
        case type, encryptedStdout, stderr, returnCode, content
    }
}

public struct CodeExecutionToolResultError: Codable, Sendable, Equatable {
    public let type = "code_execution_tool_result_error"
    public let errorCode: String

    private enum CodingKeys: String, CodingKey {
        case type, errorCode
    }
}

public enum CodeExecutionToolResultContent: Sendable, Equatable {
    case result(CodeExecutionResultBlock)
    case encryptedResult(EncryptedCodeExecutionResultBlock)
    case error(CodeExecutionToolResultError)
    case unknown(type: String, raw: JSONValue)
}

extension CodeExecutionToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "code_execution_result":
            self = .result(try CodeExecutionResultBlock(from: decoder))
        case "encrypted_code_execution_result":
            self = .encryptedResult(try EncryptedCodeExecutionResultBlock(from: decoder))
        case "code_execution_tool_result_error":
            self = .error(try CodeExecutionToolResultError(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .result(let value): try value.encode(to: encoder)
        case .encryptedResult(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

public struct CodeExecutionToolResultBlock: Codable, Sendable, Equatable {
    public let type = "code_execution_tool_result"
    public let toolUseId: String
    public let content: CodeExecutionToolResultContent

    private enum CodingKeys: String, CodingKey {
        case type, toolUseId, content
    }
}
