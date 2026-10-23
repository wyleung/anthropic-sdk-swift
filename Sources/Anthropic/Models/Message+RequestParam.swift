extension Message {
    /// This response as a message you can append to `messages` for the next request, so a multi-turn
    /// conversation doesn't have to rebuild the assistant turn block by block:
    ///
    /// ```swift
    /// let reply = try await client.messages.create(params)
    /// params = params.with(messages: params.messages + [try reply.asRequestParam(), .user("Go on.")])
    /// ```
    ///
    /// Every block is echoed back exactly as received, including `thinking` signatures, `tool_use` ids and
    /// server-tool results (web search, web fetch, code execution), which the server needs to see
    /// unchanged. Throws only for a block of a type this SDK doesn't model (`.unknown`), since the request
    /// side has no representation to carry it. Python's `Message.to_param()`.
    public func asRequestParam() throws -> MessageParam {
        MessageParam(role: role, content: try content.map { try $0.asRequestParam() })
    }
}
