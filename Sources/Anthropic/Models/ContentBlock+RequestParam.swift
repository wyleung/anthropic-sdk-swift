extension Caller {
    /// `.unknown` has no request-side representation (`CallerParam` has no such case), so it
    /// drops to `nil` rather than failing the whole conversion over a caller-metadata mismatch.
    /// `package` rather than `internal` so `AnthropicBeta`'s broader response-block echo can
    /// reuse this instead of duplicating it.
    package var asParam: CallerParam? {
        switch self {
        case .direct: return .direct
        case .codeExecution20250825(let toolId): return .codeExecution20250825(toolId: toolId)
        case .codeExecution20260120(let toolId): return .codeExecution20260120(toolId: toolId)
        case .unknown: return nil
        }
    }
}

extension TextCitation {
    /// `package` rather than `internal` so `AnthropicBeta`'s broader response-block echo can
    /// reuse this instead of duplicating it.
    package var asParam: TextCitationParam? {
        switch self {
        case .charLocation(let location):
            return .charLocation(CitationCharLocationParam(
                citedText: location.citedText,
                documentIndex: location.documentIndex,
                documentTitle: location.documentTitle,
                startCharIndex: location.startCharIndex,
                endCharIndex: location.endCharIndex
            ))
        case .pageLocation(let location):
            return .pageLocation(CitationPageLocationParam(
                citedText: location.citedText,
                documentIndex: location.documentIndex,
                documentTitle: location.documentTitle,
                startPageNumber: location.startPageNumber,
                endPageNumber: location.endPageNumber
            ))
        case .contentBlockLocation(let location):
            return .contentBlockLocation(CitationContentBlockLocationParam(
                citedText: location.citedText,
                documentIndex: location.documentIndex,
                documentTitle: location.documentTitle,
                startBlockIndex: location.startBlockIndex,
                endBlockIndex: location.endBlockIndex
            ))
        case .webSearchResultLocation(let location):
            return .webSearchResultLocation(CitationWebSearchResultLocationParam(
                citedText: location.citedText,
                encryptedIndex: location.encryptedIndex,
                title: location.title,
                url: location.url
            ))
        case .searchResultLocation(let location):
            return .searchResultLocation(CitationSearchResultLocationParam(
                citedText: location.citedText,
                source: location.source,
                title: location.title,
                startBlockIndex: location.startBlockIndex,
                endBlockIndex: location.endBlockIndex,
                searchResultIndex: location.searchResultIndex
            ))
        case .unknown:
            return nil
        }
    }
}

extension ContentBlock {
    /// Echoes a response block back into a request's message history -- what `ToolRunner` does every
    /// turn and what ``Message/asRequestParam()`` does for a whole turn. Every block kind this SDK models
    /// converts; only a block of a type it does not know (`.unknown`), or an unrecognized shape nested
    /// inside a known result block, has no request-side representation and throws instead of being
    /// silently mis-encoded.
    package func asRequestParam() throws -> ContentBlockParam {
        switch self {
        case .text(let block):
            return .text(TextBlockParam(
                text: block.text,
                citations: block.citations?.compactMap { $0.asParam }
            ))
        case .thinking(let block):
            return .thinking(ThinkingBlockParam(signature: block.signature, thinking: block.thinking))
        case .redactedThinking(let block):
            return .redactedThinking(RedactedThinkingBlockParam(data: block.data))
        case .toolUse(let block):
            return .toolUse(ToolUseBlockParam(
                id: block.id,
                name: block.name,
                input: block.input,
                caller: block.caller?.asParam,
                toolsetName: block.toolsetName
            ))
        case .serverToolUse(let block):
            return .serverToolUse(ServerToolUseBlockParam(
                id: block.id,
                name: block.name,
                input: block.input,
                caller: block.caller?.asParam
            ))
        case .webSearchToolResult(let block):
            return .webSearchToolResult(WebSearchToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam(), caller: block.caller?.asParam
            ))
        case .webFetchToolResult(let block):
            return .webFetchToolResult(WebFetchToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam(), caller: block.caller?.asParam
            ))
        case .codeExecutionToolResult(let block):
            return .codeExecutionToolResult(CodeExecutionToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            ))
        case .bashCodeExecutionToolResult(let block):
            return .bashCodeExecutionToolResult(BashCodeExecutionToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            ))
        case .textEditorCodeExecutionToolResult(let block):
            return .textEditorCodeExecutionToolResult(TextEditorCodeExecutionToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            ))
        case .toolSearchToolResult(let block):
            return .toolSearchToolResult(ToolSearchToolResultBlockParam(
                toolUseId: block.toolUseId, content: try block.content.asRequestParam()
            ))
        case .containerUpload(let block):
            return .containerUpload(ContainerUploadBlockParam(fileId: block.fileId))
        case .unknown(let type, _):
            throw Self.echoError("content block of type \"\(type)\"")
        }
    }
}

extension ContentBlock {
    /// Thrown when a response block, or a shape nested inside one, has no request-side equivalent to
    /// echo back. Shared with the Beta module.
    package static func echoError(_ typeName: String) -> AnthropicError {
        AnthropicError.responseValidation(
            message: "Can't echo an unrecognized \(typeName) back into the next request -- the "
                + "param-side union has no equivalent for it.",
            body: nil
        )
    }
}

extension WebSearchToolResultContent {
    package func asRequestParam() throws -> WebSearchToolResultBlockParamContentParam {
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
            throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}

extension DocumentSource {
    package func asRequestParam() throws -> DocumentSourceParam {
        switch self {
        case .base64PDF(let source): return .base64PDF(Base64PDFSourceParam(data: source.data))
        case .plainText(let source): return .plainText(PlainTextSourceParam(data: source.data))
        case .unknown: throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}

extension DocumentBlock {
    package func asRequestParam() throws -> DocumentBlockParam {
        DocumentBlockParam(
            source: try source.asRequestParam(),
            citations: citations.map { CitationsConfigParam(enabled: $0.enabled) },
            title: title
        )
    }
}

extension WebFetchToolResultContent {
    package func asRequestParam() throws -> WebFetchToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .result(WebFetchBlockParam(
                url: result.url, content: try result.content.asRequestParam(), retrievedAt: result.retrievedAt
            ))
        case .error(let error):
            return .error(WebFetchToolResultErrorBlockParam(errorCode: error.errorCode))
        case .unknown:
            throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}

extension CodeExecutionToolResultContent {
    package func asRequestParam() throws -> CodeExecutionToolResultBlockParamContentParam {
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
            throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}

extension BashCodeExecutionToolResultContent {
    package func asRequestParam() throws -> BashCodeExecutionToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .result(BashCodeExecutionResultBlockParam(
                stdout: result.stdout, stderr: result.stderr, returnCode: result.returnCode,
                content: result.content.map { BashCodeExecutionOutputBlockParam(fileId: $0.fileId) }
            ))
        case .error(let error):
            return .error(BashCodeExecutionToolResultErrorParam(errorCode: error.errorCode))
        case .unknown:
            throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}

extension TextEditorCodeExecutionToolResultContent {
    package func asRequestParam() throws -> TextEditorCodeExecutionToolResultBlockParamContentParam {
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
            throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}

extension ToolSearchToolResultContent {
    package func asRequestParam() throws -> ToolSearchToolResultBlockParamContentParam {
        switch self {
        case .result(let result):
            return .searchResult(ToolSearchToolSearchResultBlockParam(
                toolReferences: result.toolReferences.map { ToolReferenceBlockParam(toolName: $0.toolName) }
            ))
        case .error(let error):
            return .error(ToolSearchToolResultErrorParam(errorCode: error.errorCode, errorMessage: error.errorMessage))
        case .unknown:
            throw ContentBlock.echoError(String(describing: Self.self))
        }
    }
}
