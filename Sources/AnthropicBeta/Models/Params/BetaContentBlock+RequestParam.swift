import Foundation
import Anthropic

/// Converts a fully-`Encodable`, `Decodable`-free response payload into a `JSONValue` by
/// round-tripping it through `Data`. Used only for `BetaFallbackBlock.trigger`, whose param-side
/// counterpart is a deliberately untyped `JSONValue?` (the server accepts and ignores whatever
/// object a caller echoes back here) -- there's no hand-written `BetaFallbackRefusalTrigger` ->
/// `JSONValue` conversion to keep in sync as that type grows.
private func jsonValue(encoding value: some Encodable) throws -> JSONValue {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(JSONValue.self, from: data)
}

extension WebSearchToolResultContent {
    fileprivate func asRequestParam() throws -> WebSearchToolResultBlockParamContentParam {
        switch self {
        case .results(let results):
            return .results(results.map {
                WebSearchResultBlockParam(
                    title: $0.title, url: $0.url, encryptedContent: $0.encryptedContent, pageAge: $0.pageAge
                )
            })
        case .error(let error):
            return .error(WebSearchToolRequestErrorParam(errorCode: error.errorCode))
        case .unknown:
            throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension DocumentSource {
    fileprivate func asRequestParam() throws -> DocumentSourceParam {
        switch self {
        case .base64PDF(let source): return .base64PDF(Base64PDFSourceParam(data: source.data))
        case .plainText(let source): return .plainText(PlainTextSourceParam(data: source.data))
        case .unknown: throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension DocumentBlock {
    fileprivate func asRequestParam() throws -> DocumentBlockParam {
        DocumentBlockParam(
            source: try source.asRequestParam(),
            citations: citations.map { CitationsConfigParam(enabled: $0.enabled) },
            title: title
        )
    }
}

extension WebFetchToolResultContent {
    fileprivate func asRequestParam() throws -> WebFetchToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .result(WebFetchBlockParam(
                url: result.url, content: try result.content.asRequestParam(), retrievedAt: result.retrievedAt
            ))
        case .error(let error):
            return .error(WebFetchToolResultErrorBlockParam(errorCode: error.errorCode))
        case .unknown:
            throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension CodeExecutionToolResultContent {
    fileprivate func asRequestParam() throws -> CodeExecutionToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .result(CodeExecutionResultBlockParam(
                stdout: result.stdout, stderr: result.stderr, returnCode: result.returnCode,
                content: result.content.map { CodeExecutionOutputBlockParam(fileId: $0.fileId) }
            ))
        case .encryptedResult(let result):
            return .encryptedResult(EncryptedCodeExecutionResultBlockParam(
                encryptedStdout: result.encryptedStdout, stderr: result.stderr, returnCode: result.returnCode,
                content: result.content.map { CodeExecutionOutputBlockParam(fileId: $0.fileId) }
            ))
        case .error(let error):
            return .error(CodeExecutionToolResultErrorParam(errorCode: error.errorCode))
        case .unknown:
            throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension BashCodeExecutionToolResultContent {
    fileprivate func asRequestParam() throws -> BashCodeExecutionToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .result(BashCodeExecutionResultBlockParam(
                stdout: result.stdout, stderr: result.stderr, returnCode: result.returnCode,
                content: result.content.map { BashCodeExecutionOutputBlockParam(fileId: $0.fileId) }
            ))
        case .error(let error):
            return .error(BashCodeExecutionToolResultErrorParam(errorCode: error.errorCode))
        case .unknown:
            throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension TextEditorCodeExecutionToolResultContent {
    fileprivate func asRequestParam() throws -> TextEditorCodeExecutionToolResultBlockParamContentParam {
        switch self {
        case .view(let result):
            return .view(TextEditorCodeExecutionViewResultBlockParam(
                content: result.content, fileType: result.fileType, numLines: result.numLines,
                startLine: result.startLine, totalLines: result.totalLines
            ))
        case .create(let result):
            return .create(TextEditorCodeExecutionCreateResultBlockParam(isFileUpdate: result.isFileUpdate))
        case .strReplace(let result):
            return .strReplace(TextEditorCodeExecutionStrReplaceResultBlockParam(
                lines: result.lines, newLines: result.newLines, newStart: result.newStart,
                oldLines: result.oldLines, oldStart: result.oldStart
            ))
        case .error(let error):
            return .error(TextEditorCodeExecutionToolResultErrorParam(
                errorCode: error.errorCode, errorMessage: error.errorMessage
            ))
        case .unknown:
            throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension ToolSearchToolResultContent {
    fileprivate func asRequestParam() throws -> ToolSearchToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .searchResult(ToolSearchToolSearchResultBlockParam(
                toolReferences: result.toolReferences.map { ToolReferenceBlockParam(toolName: $0.toolName) }
            ))
        case .error(let error):
            return .error(ToolSearchToolResultErrorParam(errorCode: error.errorCode, errorMessage: error.errorMessage))
        case .unknown:
            throw BetaToolRunner.echoError(String(describing: Self.self))
        }
    }
}

extension BetaMCPToolResultBlock.Content {
    fileprivate func asRequestParam() -> BetaRequestMCPToolResultBlockParam.Content {
        switch self {
        case .text(let text): return .text(text)
        case .blocks(let blocks):
            return .blocks(blocks.map { TextBlockParam(text: $0.text, citations: $0.citations?.compactMap { $0.asParam }) })
        }
    }
}

extension BetaContentBlock {
    /// Echoes an assistant response block back into the next request's message history, as
    /// `BetaToolRunner`'s loop needs to do every iteration. Unlike GA's `ContentBlock.asRequestParam()`
    /// -- which only covers the 5 block kinds a custom-tool-only conversation can produce, since
    /// GA's `ToolRunner` never declares server tools -- `BetaToolUnionParam` lets a caller declare
    /// server tools (web search, code execution, MCP toolsets, advisors, tool search) right alongside
    /// custom ones, so a real Beta conversation's assistant turns can legitimately contain any of
    /// these kinds. This covers all 17 typed cases plus `.unknown`; only the handful of inner
    /// "unrecognized content shape" cases nested inside a *known* result-block type have no
    /// request-side representation to fall back to and throw instead.
    func asRequestParam() throws -> BetaContentBlockParam {
        switch self {
        case .text(let block):
            return .standard(.text(TextBlockParam(
                text: block.text, citations: block.citations?.compactMap { $0.asParam }
            )))
        case .thinking(let block):
            return .standard(.thinking(ThinkingBlockParam(signature: block.signature, thinking: block.thinking)))
        case .redactedThinking(let block):
            return .standard(.redactedThinking(RedactedThinkingBlockParam(data: block.data)))
        case .toolUse(let block):
            return .standard(.toolUse(ToolUseBlockParam(
                id: block.id, name: block.name, input: block.input,
                caller: block.caller?.asParam, toolsetName: block.toolsetName
            )))
        case .serverToolUse(let block):
            return .standard(.serverToolUse(ServerToolUseBlockParam(
                id: block.id, name: block.name, input: block.input, caller: block.caller?.asParam
            )))
        case .webSearchToolResult(let block):
            return .standard(.webSearchToolResult(WebSearchToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam(), caller: block.caller?.asParam
            )))
        case .webFetchToolResult(let block):
            return .standard(.webFetchToolResult(WebFetchToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam(), caller: block.caller?.asParam
            )))
        case .codeExecutionToolResult(let block):
            return .standard(.codeExecutionToolResult(CodeExecutionToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            )))
        case .bashCodeExecutionToolResult(let block):
            return .standard(.bashCodeExecutionToolResult(BashCodeExecutionToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            )))
        case .textEditorCodeExecutionToolResult(let block):
            return .standard(.textEditorCodeExecutionToolResult(TextEditorCodeExecutionToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            )))
        case .toolSearchToolResult(let block):
            return .standard(.toolSearchToolResult(ToolSearchToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            )))
        case .containerUpload(let block):
            return .standard(.containerUpload(ContainerUploadBlockParam(fileId: block.fileId)))
        case .advisorToolResult(let block):
            return .advisorToolResult(BetaAdvisorToolResultBlockParam(
                content: block.content, toolUseId: block.toolUseId
            ))
        case .mcpToolUse(let block):
            return .mcpToolUse(BetaMCPToolUseBlockParam(
                id: block.id, input: block.input, name: block.name, serverName: block.serverName
            ))
        case .mcpToolResult(let block):
            return .mcpToolResult(BetaRequestMCPToolResultBlockParam(
                toolUseId: block.toolUseId, content: block.content.asRequestParam(), isError: block.isError
            ))
        case .compaction(let block):
            return .compaction(BetaCompactionBlockParam(content: block.content, encryptedContent: block.encryptedContent))
        case .fallback(let block):
            return .fallback(BetaFallbackBlockParam(
                to: block.to, from: block.from, trigger: try jsonValue(encoding: block.trigger)
            ))
        case .unknown(_, let raw):
            return .raw(raw)
        }
    }
}
