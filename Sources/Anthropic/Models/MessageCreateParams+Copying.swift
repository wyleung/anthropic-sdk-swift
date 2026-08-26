extension MessageCreateParams {
    /// Every field is `let`, so growing the conversation for the next loop iteration (`ToolRunner`)
    /// or splicing in a tool registry's wire-format declarations needs a full reconstruction rather
    /// than in-place mutation.
    func with(messages: [MessageParam]? = nil, tools: [ToolUnionParam]? = nil) -> MessageCreateParams {
        MessageCreateParams(
            model: model,
            maxTokens: maxTokens,
            messages: messages ?? self.messages,
            cacheControl: cacheControl,
            container: container,
            inferenceGeo: inferenceGeo,
            metadata: metadata,
            outputConfig: outputConfig,
            serviceTier: serviceTier,
            stopSequences: stopSequences,
            system: system,
            thinking: thinking,
            toolChoice: toolChoice,
            tools: tools ?? self.tools
        )
    }
}
