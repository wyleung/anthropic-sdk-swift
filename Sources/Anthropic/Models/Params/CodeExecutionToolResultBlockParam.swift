public struct CodeExecutionOutputBlockParam: Encodable, Sendable, Equatable {
    public let type = "code_execution_output"
    public let fileId: String

    public init(fileId: String) {
        self.fileId = fileId
    }
}

public struct CodeExecutionResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "code_execution_result"
    public let stdout: String
    public let stderr: String
    public let returnCode: Int
    public let content: [CodeExecutionOutputBlockParam]

    public init(stdout: String, stderr: String, returnCode: Int, content: [CodeExecutionOutputBlockParam]) {
        self.stdout = stdout
        self.stderr = stderr
        self.returnCode = returnCode
        self.content = content
    }
}

public struct EncryptedCodeExecutionResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "encrypted_code_execution_result"
    public let encryptedStdout: String
    public let stderr: String
    public let returnCode: Int
    public let content: [CodeExecutionOutputBlockParam]

    public init(encryptedStdout: String, stderr: String, returnCode: Int, content: [CodeExecutionOutputBlockParam]) {
        self.encryptedStdout = encryptedStdout
        self.stderr = stderr
        self.returnCode = returnCode
        self.content = content
    }
}

public struct CodeExecutionToolResultErrorParam: Encodable, Sendable, Equatable {
    public let type = "code_execution_tool_result_error"
    public let errorCode: String

    public init(errorCode: String) {
        self.errorCode = errorCode
    }
}

public enum CodeExecutionToolResultBlockParamContentParam: Sendable, Equatable {
    case error(CodeExecutionToolResultErrorParam)
    case result(CodeExecutionResultBlockParam)
    case encryptedResult(EncryptedCodeExecutionResultBlockParam)
}

extension CodeExecutionToolResultBlockParamContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .error(let value): try container.encode(value)
        case .result(let value): try container.encode(value)
        case .encryptedResult(let value): try container.encode(value)
        }
    }
}

public struct CodeExecutionToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "code_execution_tool_result"
    public let toolUseId: String
    public let content: CodeExecutionToolResultBlockParamContentParam
    public let cacheControl: CacheControlEphemeral?

    public init(
        toolUseId: String,
        content: CodeExecutionToolResultBlockParamContentParam,
        cacheControl: CacheControlEphemeral? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.cacheControl = cacheControl
    }
}
