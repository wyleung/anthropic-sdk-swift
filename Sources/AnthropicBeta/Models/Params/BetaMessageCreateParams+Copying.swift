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
            compaction: compaction,
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

    /// Whether `context_management` already carries a compaction edit (`compact_*`). The compaction
    /// request is sent without `context_management`, so the API cannot reject the combination there: it
    /// would run and bill the compaction, then reject the next request, where the compaction response
    /// and the compaction edit meet.
    var hasCompactionEdit: Bool {
        guard case .array(let edits)? = contextManagement?["edits"] else { return false }
        return edits.contains { $0["type"]?.stringValue?.hasPrefix("compact_") == true }
    }

    /// The request that compacts this conversation. It returns only the compaction block, never a
    /// reply, so the API rejects the params that only shape a reply -- `context_management`,
    /// `stop_sequences`, a forcing `tool_choice` (`any` / `tool`) and the structured-output `format`
    /// (also inside each fallback's `output_config`). The runner's later requests keep them.
    ///
    /// Written out field by field like `with(...)`, so a field added to the params has to be threaded
    /// through here too; a test fails if one is dropped.
    func forCompactionRequest(_ compaction: BetaCompactionConfigParam) -> BetaMessageCreateParams {
        let forcesATool: Bool
        switch toolChoice {
        case .any?, .tool?: forcesATool = true
        default: forcesATool = false
        }
        return BetaMessageCreateParams(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            cacheControl: cacheControl,
            compaction: compaction,
            container: container,
            contextManagement: nil,
            diagnostics: diagnostics,
            fallbackCreditToken: fallbackCreditToken,
            fallbacks: fallbacks.map(Self.withoutOutputFormats),
            inferenceGeo: inferenceGeo,
            mcpServers: mcpServers,
            metadata: metadata,
            outputConfig: outputConfig.map {
                BetaOutputConfigParam(effort: $0.effort, format: nil, taskBudget: $0.taskBudget)
            },
            serviceTier: serviceTier,
            speed: speed,
            stopSequences: nil,
            system: system,
            thinking: thinking,
            toolChoice: forcesATool ? nil : toolChoice,
            tools: tools
        )
    }

    /// `fallbacks` is an array of objects, each of which may carry its own `output_config`; drop the
    /// `format` from those. Anything of another shape is passed through untouched.
    private static func withoutOutputFormats(_ fallbacks: JSONValue) -> JSONValue {
        guard case .array(let entries) = fallbacks else { return fallbacks }
        return .array(entries.map { entry in
            guard case .object(var fields) = entry, case .object(var outputConfig)? = fields["output_config"] else {
                return entry
            }
            outputConfig.removeValue(forKey: "format")
            fields["output_config"] = .object(outputConfig)
            return .object(fields)
        })
    }
}
