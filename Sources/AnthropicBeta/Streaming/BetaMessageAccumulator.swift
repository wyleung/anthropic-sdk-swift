import Anthropic

/// Builds the higher-level `BetaMessageStreamEvent`s that accompany one raw stream event, given
/// the `BetaMessage` snapshot *after* that event has been folded in by
/// `BetaMessageAccumulator.accumulate`. Ported field-for-field from
/// `lib/streaming/_beta_messages.py`'s `build_events`.
///
/// Structurally identical to GA's `buildMessageStreamEvents`, with two additions: tool-input
/// tracking covers `.mcpToolUse` in addition to GA's `.toolUse`/`.serverToolUse` (Python's
/// `TRACKS_TOOL_INPUT` is a 3-tuple here, not GA's 2-tuple), and `compaction_delta` against a
/// `.compaction` block fires a `BetaCompactionEvent` carrying that block's post-update state.
func buildBetaMessageStreamEvents(
    for event: BetaRawMessageStreamEvent, snapshot: BetaMessage
) throws -> [BetaMessageStreamEvent] {
    switch event {
    case .messageStart(let start):
        return [.messageStart(start)]
    case .messageDelta(let delta):
        return [.messageDelta(delta)]
    case .messageStop:
        return [.messageStop(BetaMessageStopEvent(message: snapshot))]
    case .contentBlockStart(let start):
        return [.contentBlockStart(start)]
    case .contentBlockStop(let stop):
        guard snapshot.content.indices.contains(stop.index) else {
            throw AnthropicError.responseValidation(
                message: "Received content_block_stop for index \(stop.index), which was never started.",
                body: nil
            )
        }
        return [.contentBlockStop(BetaContentBlockStopEvent(index: stop.index, contentBlock: snapshot.content[stop.index]))]
    case .contentBlockDelta(let delta):
        var events: [BetaMessageStreamEvent] = [.contentBlockDelta(delta)]
        guard snapshot.content.indices.contains(delta.index) else { return events }
        let block = snapshot.content[delta.index]

        switch (delta.delta, block) {
        case (.text(let textDelta), .text(let textBlock)):
            events.append(.text(BetaTextEvent(text: textDelta.text, snapshot: textBlock.text)))
        case (.citations(let citationsDelta), .text(let textBlock)):
            events.append(.citation(BetaCitationEvent(citation: citationsDelta.citation, snapshot: textBlock.citations ?? [])))
        case (.thinking(let thinkingDelta), .thinking(let thinkingBlock)):
            events.append(.thinking(BetaThinkingEvent(thinking: thinkingDelta.thinking, snapshot: thinkingBlock.thinking)))
        case (.signature, .thinking(let thinkingBlock)):
            events.append(.signature(BetaSignatureEvent(signature: thinkingBlock.signature)))
        case (.inputJSON(let jsonDelta), .toolUse(let toolUse)):
            events.append(.inputJSON(BetaInputJSONEvent(partialJSON: jsonDelta.partialJson, snapshot: toolUse.input)))
        case (.inputJSON(let jsonDelta), .serverToolUse(let serverToolUse)):
            events.append(.inputJSON(BetaInputJSONEvent(partialJSON: jsonDelta.partialJson, snapshot: serverToolUse.input)))
        case (.inputJSON(let jsonDelta), .mcpToolUse(let mcpToolUse)):
            events.append(.inputJSON(BetaInputJSONEvent(partialJSON: jsonDelta.partialJson, snapshot: .object(mcpToolUse.input))))
        case (.compaction, .compaction(let compactionBlock)):
            events.append(.compaction(BetaCompactionEvent(content: compactionBlock.content, encryptedContent: compactionBlock.encryptedContent)))
        default:
            break
        }
        return events
    case .unknown:
        return []
    }
}

/// Folds raw per-chunk stream events into a growing `BetaMessage` snapshot, ported field-for-field
/// from `lib/streaming/_beta_messages.py`'s `accumulate_event`. Structurally identical to GA's
/// `MessageAccumulator`, plus three Beta-only behaviors: (1) a `content_block_start` whose block
/// is `.fallback` overwrites the snapshot's top-level `model` with the fallback's target model,
/// keeping the snapshot's `model` consistent with the relabeled non-streaming message; (2)
/// tool-input buffering additionally covers `.mcpToolUse`, whose `input` is `[String: JSONValue]`
/// rather than a plain `JSONValue`, so buffered JSON is unwrapped from the parsed object; (3) a
/// `compaction_delta` fully replaces (never appends to) its block's `content`/`encryptedContent`.
///
/// `PartialJSON.parse` has only one leniency mode, matching the Python SDK's default
/// `partial_mode=True`. The Python accumulator switches to the more lenient
/// `partial_mode="trailing-strings"` when the request's `anthropic-beta` header contains
/// `"fine-grained-tool-streaming-2025-05-14"`; this port does not replicate that conditional
/// leniency and always parses with the single mode `PartialJSON.parse` implements.
struct BetaMessageAccumulator {
    private(set) var snapshot: BetaMessage?
    private var toolInputBuffers: [Int: String] = [:]

    @discardableResult
    mutating func accumulate(_ event: BetaRawMessageStreamEvent) throws -> BetaMessage {
        guard var current = snapshot else {
            guard case .messageStart(let start) = event else {
                throw AnthropicError.responseValidation(
                    message: "Unexpected event order: the stream must begin with a message_start event.",
                    body: nil
                )
            }
            snapshot = start.message
            return start.message
        }

        switch event {
        case .contentBlockStart(let start):
            var model = current.model
            if case .fallback(let fallback) = start.contentBlock {
                model = fallback.to.model
            }
            current = BetaMessage(
                id: current.id,
                content: current.content + [start.contentBlock],
                model: model, container: current.container,
                contextManagement: current.contextManagement, diagnostics: current.diagnostics,
                stopReason: current.stopReason, stopSequence: current.stopSequence,
                stopDetails: current.stopDetails, usage: current.usage
            )
        case .contentBlockDelta(let delta):
            current = try Self.applying(delta, to: current, buffers: &toolInputBuffers)
        case .messageDelta(let delta):
            current = Self.applying(delta, to: current)
        case .messageStart, .messageStop, .contentBlockStop, .unknown:
            break
        }

        snapshot = current
        return current
    }

    private static func applying(_ delta: BetaRawMessageDeltaEvent, to message: BetaMessage) -> BetaMessage {
        let usage = message.usage
        let updatedUsage = BetaUsage(
            cacheCreation: usage.cacheCreation,
            cacheCreationInputTokens: delta.usage.cacheCreationInputTokens ?? usage.cacheCreationInputTokens,
            cacheReadInputTokens: delta.usage.cacheReadInputTokens ?? usage.cacheReadInputTokens,
            fallbackCredit: delta.usage.fallbackCredit ?? usage.fallbackCredit,
            inferenceGeo: usage.inferenceGeo,
            inputTokens: delta.usage.inputTokens ?? usage.inputTokens,
            iterations: delta.usage.iterations ?? usage.iterations,
            outputTokens: delta.usage.outputTokens,
            outputTokensDetails: delta.usage.outputTokensDetails ?? usage.outputTokensDetails,
            serverToolUse: delta.usage.serverToolUse ?? usage.serverToolUse,
            serviceTier: usage.serviceTier,
            speed: usage.speed
        )
        return BetaMessage(
            id: message.id, content: message.content, model: message.model,
            container: delta.delta.container ?? message.container,
            contextManagement: delta.contextManagement ?? message.contextManagement,
            diagnostics: message.diagnostics,
            stopReason: delta.delta.stopReason,
            stopSequence: delta.delta.stopSequence,
            stopDetails: delta.delta.stopDetails,
            usage: updatedUsage
        )
    }

    private static func applying(
        _ delta: BetaRawContentBlockDeltaEvent,
        to message: BetaMessage,
        buffers: inout [Int: String]
    ) throws -> BetaMessage {
        guard message.content.indices.contains(delta.index) else {
            throw AnthropicError.responseValidation(
                message: "Received content_block_delta for index \(delta.index), which was never started.",
                body: nil
            )
        }

        var content = message.content
        let block = content[delta.index]

        switch (delta.delta, block) {
        case (.text(let textDelta), .text(let textBlock)):
            content[delta.index] = .text(TextBlock(text: textBlock.text + textDelta.text, citations: textBlock.citations))
        case (.citations(let citationsDelta), .text(let textBlock)):
            content[delta.index] = .text(TextBlock(
                text: textBlock.text,
                citations: (textBlock.citations ?? []) + [citationsDelta.citation]
            ))
        case (.thinking(let thinkingDelta), .thinking(let thinkingBlock)):
            content[delta.index] = .thinking(ThinkingBlock(
                thinking: thinkingBlock.thinking + thinkingDelta.thinking,
                signature: thinkingBlock.signature
            ))
        case (.signature(let signatureDelta), .thinking(let thinkingBlock)):
            content[delta.index] = .thinking(ThinkingBlock(
                thinking: thinkingBlock.thinking,
                signature: signatureDelta.signature
            ))
        case (.inputJSON(let jsonDelta), .toolUse(let toolUse)):
            let buffer = (buffers[delta.index] ?? "") + jsonDelta.partialJson
            buffers[delta.index] = buffer
            if !buffer.isEmpty {
                content[delta.index] = .toolUse(ToolUseBlock(
                    id: toolUse.id, name: toolUse.name, input: try PartialJSON.parse(buffer),
                    caller: toolUse.caller, toolsetName: toolUse.toolsetName
                ))
            }
        case (.inputJSON(let jsonDelta), .serverToolUse(let serverToolUse)):
            let buffer = (buffers[delta.index] ?? "") + jsonDelta.partialJson
            buffers[delta.index] = buffer
            if !buffer.isEmpty {
                content[delta.index] = .serverToolUse(ServerToolUseBlock(
                    id: serverToolUse.id, name: serverToolUse.name, input: try PartialJSON.parse(buffer),
                    caller: serverToolUse.caller
                ))
            }
        case (.inputJSON(let jsonDelta), .mcpToolUse(let mcpToolUse)):
            let buffer = (buffers[delta.index] ?? "") + jsonDelta.partialJson
            buffers[delta.index] = buffer
            if !buffer.isEmpty, case .object(let parsed) = try PartialJSON.parse(buffer) {
                content[delta.index] = .mcpToolUse(BetaMCPToolUseBlock(
                    id: mcpToolUse.id, input: parsed, name: mcpToolUse.name, serverName: mcpToolUse.serverName
                ))
            }
        case (.compaction(let compactionDelta), .compaction):
            content[delta.index] = .compaction(BetaCompactionBlock(
                content: compactionDelta.content, encryptedContent: compactionDelta.encryptedContent
            ))
        default:
            break
        }

        return BetaMessage(
            id: message.id, content: content, model: message.model, container: message.container,
            contextManagement: message.contextManagement, diagnostics: message.diagnostics,
            stopReason: message.stopReason, stopSequence: message.stopSequence,
            stopDetails: message.stopDetails, usage: message.usage
        )
    }
}
