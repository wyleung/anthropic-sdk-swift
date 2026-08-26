public struct BashCodeExecutionOutputBlockParam: Encodable, Sendable, Equatable {
    public let type = "bash_code_execution_output"
    public let fileId: String

    public init(fileId: String) {
        self.fileId = fileId
    }
}

public struct BashCodeExecutionResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "bash_code_execution_result"
    public let stdout: String
    public let stderr: String
    public let returnCode: Int
    public let content: [BashCodeExecutionOutputBlockParam]

    public init(stdout: String, stderr: String, returnCode: Int, content: [BashCodeExecutionOutputBlockParam]) {
        self.stdout = stdout
        self.stderr = stderr
        self.returnCode = returnCode
        self.content = content
    }
}

public struct BashCodeExecutionToolResultErrorParam: Encodable, Sendable, Equatable {
    public let type = "bash_code_execution_tool_result_error"
    public let errorCode: String

    public init(errorCode: String) {
        self.errorCode = errorCode
    }
}

public enum BashCodeExecutionToolResultBlockParamContentParam: Sendable, Equatable {
    case error(BashCodeExecutionToolResultErrorParam)
    case result(BashCodeExecutionResultBlockParam)
}

extension BashCodeExecutionToolResultBlockParamContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .error(let value): try container.encode(value)
        case .result(let value): try container.encode(value)
        }
    }
}

public struct BashCodeExecutionToolResultBlockParam: Encodable, Sendable, Equatable {
    public let type = "bash_code_execution_tool_result"
    public let toolUseId: String
    public let content: BashCodeExecutionToolResultBlockParamContentParam
    public let cacheControl: CacheControlEphemeral?

    public init(
        toolUseId: String,
        content: BashCodeExecutionToolResultBlockParamContentParam,
        cacheControl: CacheControlEphemeral? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.cacheControl = cacheControl
    }
}
