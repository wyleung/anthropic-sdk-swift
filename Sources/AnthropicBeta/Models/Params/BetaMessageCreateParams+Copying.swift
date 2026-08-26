import Anthropic

extension BetaMessageCreateParams {
    /// Every field is `let`, so growing the conversation for the next loop iteration
    /// (`BetaToolRunner`), splicing in a tool registry's wire-format declarations, or propagating
    /// a server-assigned container id needs a full reconstruction rather than in-place mutation.
    /// Unlike GA's `MessageCreateParams.with(messages:tools:)`, this also threads through
    /// `container` -- `BetaToolRunner` is the first caller that needs to rewrite it mid-loop.
    func with(
        messages: [BetaMessageParam]? = nil,
        tools: [BetaToolUnionParam]? = nil,
        container: MessageCreateParamsContainerParam? = nil
    ) -> BetaMessageCreateParams {
        BetaMessageCreateParams(
            model: model,
            maxTokens: maxTokens,
            messages: messages ?? self.messages,
            cacheControl: cacheControl,
            container: container ?? self.container,
            contextManagement: contextManagement,
            diagnostics: diagnostics,
            fallbackCreditToken: fallbackCreditToken,
            fallbacks: fallbacks,
            inferenceGeo: inferenceGeo,
            mcpServers: mcpServers,
            metadata: metadata,
            outputConfig: outputConfig,
            serviceTier: serviceTier,
            speed: speed,
            stopSequences: stopSequences,
            system: system,
            thinking: thinking,
            toolChoice: toolChoice,
            tools: tools ?? self.tools
        )
    }
}
