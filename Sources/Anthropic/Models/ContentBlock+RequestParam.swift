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
    /// Echoes an assistant response block back into the next request's message history, as
    /// `ToolRunner`'s loop needs to do every iteration. Only the block kinds that can actually
    /// appear in a custom-tool-only turn are supported; the server-tool-result-shaped cases (and
    /// `.unknown`) can't occur there in practice, since `ToolRunner` never declares server tools,
    /// so they throw rather than silently mis-encoding.
    func asRequestParam() throws -> ContentBlockParam {
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
        default:
            throw AnthropicError.responseValidation(
                message: "ToolRunner can't echo a \(Self.self) response block back into the next "
                    + "request -- server-tool-result content is never expected in a custom-tool-only "
                    + "conversation.",
                body: nil
            )
        }
    }
}
