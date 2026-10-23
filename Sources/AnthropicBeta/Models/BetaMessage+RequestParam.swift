import Anthropic

extension BetaMessage {
    /// This response as a message you can append to `messages` for the next request. Every block is
    /// echoed back as received -- including `compaction` blocks (whose `signature` and `toolChanges` must
    /// come back verbatim), `fallback`, MCP, advisor and server-tool blocks -- and a block of a type this
    /// SDK doesn't model is passed through raw. Throws only for an unrecognized shape nested inside a
    /// known result block, which the request side can't represent. Python's `BetaMessage.to_param()`.
    public func asRequestParam() throws -> BetaMessageParam {
        BetaMessageParam(role: .assistant, content: try content.map { try $0.asRequestParam() })
    }
}
