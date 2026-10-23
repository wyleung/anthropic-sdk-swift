import Foundation
import Anthropic

/// Converts a response payload into the `JSONValue` that goes back on the wire, by round-tripping it
/// through `Data`. Used where the param side is deliberately untyped: `BetaFallbackBlock.trigger` (the
/// server accepts and ignores whatever object a caller echoes back) and a compaction block's
/// `toolChanges` (which must be echoed back unchanged, including entry types newer than this port).
///
/// The JSON is *wire-shaped*: encoded with the transport's snake_case encoder, so `serverName` becomes
/// `server_name`. That matters because keys inside a `JSONValue` are plain dictionary keys, which the
/// request encoder never converts afterwards -- a camelCase key left here would be sent as-is. It is
/// decoded with a plain decoder, since there is nothing left to convert.
private func jsonValue(encoding value: some Encodable) throws -> JSONValue {
    let data = try HTTPTransport.encoder.encode(value)
    return try JSONDecoder().decode(JSONValue.self, from: data)
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
    /// `BetaToolRunner`'s loop needs to do every iteration and ``BetaMessage/asRequestParam()`` does for
    /// a whole turn. A real Beta conversation's assistant turns can contain any of the 17 typed kinds
    /// (server tools, MCP, advisors, compaction, ...), plus `.unknown`, which is passed through raw. Only
    /// an unrecognized shape nested inside a *known* result block has no request-side representation
    /// and throws instead.
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
        case .mcpToolListing(let block):
            return .mcpToolListing(BetaMCPToolListingBlockParam(
                mcpServerName: block.mcpServerName,
                tools: block.tools.map {
                    BetaMCPToolParam(name: $0.name, inputSchema: $0.inputSchema, description: $0.description)
                }
            ))
        case .compaction(let block):
            return .compaction(BetaCompactionBlockParam(
                content: block.content, encryptedContent: block.encryptedContent, signature: block.signature,
                toolChanges: try block.toolChanges?.map { .raw(try jsonValue(encoding: $0)) }
            ))
        case .fallback(let block):
            return .fallback(BetaFallbackBlockParam(
                to: block.to, from: block.from, trigger: try jsonValue(encoding: block.trigger)
            ))
        case .unknown(_, let raw):
            return .raw(raw)
        }
    }
}
