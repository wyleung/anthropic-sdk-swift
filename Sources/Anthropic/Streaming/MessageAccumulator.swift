/// Builds the higher-level `MessageStreamEvent`s that accompany one raw stream event, given the
/// `Message` snapshot *after* that event has been folded in by `MessageAccumulator.accumulate`.
/// Ported field-for-field from `lib/streaming/_messages.py`'s `build_events`.
///
/// `message_start`/`message_delta`/`content_block_start` pass their raw event through unchanged.
/// `message_stop`/`content_block_stop` are replaced by an enriched event carrying the snapshot
/// (the raw events themselves carry no useful payload). `content_block_delta` always passes its
/// raw event through, plus -- only when the delta's case matches the post-update content block's
/// case -- a derived convenience event built from that block's accumulated state.
func buildMessageStreamEvents(for event: RawMessageStreamEvent, snapshot: Message) throws -> [MessageStreamEvent] {
    switch event {
    case .messageStart(let start):
        return [.messageStart(start)]
    case .messageDelta(let delta):
        return [.messageDelta(delta)]
    case .messageStop:
        return [.messageStop(MessageStopEvent(message: snapshot))]
    case .contentBlockStart(let start):
        return [.contentBlockStart(start)]
    case .contentBlockStop(let stop):
        guard snapshot.content.indices.contains(stop.index) else {
            throw AnthropicError.responseValidation(
                message: "Received content_block_stop for index \(stop.index), which was never started.",
                body: nil
            )
        }
        return [.contentBlockStop(ContentBlockStopEvent(index: stop.index, contentBlock: snapshot.content[stop.index]))]
    case .contentBlockDelta(let delta):
        var events: [MessageStreamEvent] = [.contentBlockDelta(delta)]
        guard snapshot.content.indices.contains(delta.index) else { return events }
        let block = snapshot.content[delta.index]

        switch (delta.delta, block) {
        case (.text(let textDelta), .text(let textBlock)):
            events.append(.text(TextEvent(text: textDelta.text, snapshot: textBlock.text)))
        case (.citations(let citationsDelta), .text(let textBlock)):
            events.append(.citation(CitationEvent(citation: citationsDelta.citation, snapshot: textBlock.citations ?? [])))
        case (.thinking(let thinkingDelta), .thinking(let thinkingBlock)):
            events.append(.thinking(ThinkingEvent(thinking: thinkingDelta.thinking, snapshot: thinkingBlock.thinking)))
        case (.signature, .thinking(let thinkingBlock)):
            events.append(.signature(SignatureEvent(signature: thinkingBlock.signature)))
        case (.inputJSON(let jsonDelta), .toolUse(let toolUse)):
            events.append(.inputJSON(InputJSONEvent(partialJSON: jsonDelta.partialJson, snapshot: toolUse.input)))
        case (.inputJSON(let jsonDelta), .serverToolUse(let serverToolUse)):
            events.append(.inputJSON(InputJSONEvent(partialJSON: jsonDelta.partialJson, snapshot: serverToolUse.input)))
        default:
            break
        }
        return events
    case .unknown:
        return []
    }
}

/// Folds raw per-chunk stream events into a growing `Message` snapshot, ported field-for-field
/// from `lib/streaming/_messages.py`'s `accumulate_event`. Python mutates its snapshot's content
/// blocks in place via a hidden `__json_buf` attribute stashed directly on the block object; since
/// this port's content-block structs are `let`-only value types, that per-index raw-JSON buffer is
/// instead tracked externally in `toolInputBuffers`, and every delta application reconstructs a
/// fresh `Message`/`ContentBlock` rather than mutating one.
struct MessageAccumulator {
    private(set) var snapshot: Message?
    private var toolInputBuffers: [Int: String] = [:]

    /// Folds `event` into the snapshot and returns the updated snapshot.
    ///
    /// `content_block_stop` and `message_stop` are no-ops here -- matching Python, where
    /// `accumulate_event`'s elif chain has no branch for either, and finalization is implicit in
    /// having consumed every event.
    @discardableResult
    mutating func accumulate(_ event: RawMessageStreamEvent) throws -> Message {
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
            current = Message(
                id: current.id, type: current.type, role: current.role,
                content: current.content + [start.contentBlock],
                model: current.model, container: current.container,
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

    private static func applying(_ delta: RawMessageDeltaEvent, to message: Message) -> Message {
        let usage = message.usage
        let updatedUsage = Usage(
            inputTokens: delta.usage.inputTokens ?? usage.inputTokens,
            outputTokens: delta.usage.outputTokens,
            cacheCreation: usage.cacheCreation,
            cacheCreationInputTokens: delta.usage.cacheCreationInputTokens ?? usage.cacheCreationInputTokens,
            cacheReadInputTokens: delta.usage.cacheReadInputTokens ?? usage.cacheReadInputTokens,
            inferenceGeo: usage.inferenceGeo,
            outputTokensDetails: delta.usage.outputTokensDetails ?? usage.outputTokensDetails,
            serverToolUse: delta.usage.serverToolUse ?? usage.serverToolUse,
            serviceTier: usage.serviceTier
        )
        return Message(
            id: message.id, type: message.type, role: message.role, content: message.content,
            model: message.model,
            container: delta.delta.container ?? message.container,
            stopReason: delta.delta.stopReason,
            stopSequence: delta.delta.stopSequence,
            stopDetails: delta.delta.stopDetails,
            usage: updatedUsage
        )
    }

    private static func applying(
        _ delta: RawContentBlockDeltaEvent,
        to message: Message,
        buffers: inout [Int: String]
    ) throws -> Message {
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
        default:
            break
        }

        return Message(
            id: message.id, type: message.type, role: message.role, content: content,
            model: message.model, container: message.container,
            stopReason: message.stopReason, stopSequence: message.stopSequence,
            stopDetails: message.stopDetails, usage: message.usage
        )
    }
}
