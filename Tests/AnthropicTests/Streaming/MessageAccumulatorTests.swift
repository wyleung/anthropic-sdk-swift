import XCTest
@testable import Anthropic

final class MessageAccumulatorTests: XCTestCase {
    private func decode(_ json: String) throws -> RawMessageStreamEvent {
        try HTTPTransport.decoder.decode(RawMessageStreamEvent.self, from: Data(json.utf8))
    }

    private let messageStart = #"""
    {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant",
    "model":"claude-opus-5","content":[],"usage":{"input_tokens":10,"output_tokens":0}}}
    """#

    func testAccumulateThrowsIfTheStreamDoesNotBeginWithMessageStart() throws {
        var accumulator = MessageAccumulator()
        let stop = try decode(#"{"type":"message_stop"}"#)
        XCTAssertThrowsError(try accumulator.accumulate(stop)) { error in
            guard case AnthropicError.responseValidation = error else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
        }
    }

    func testMessageStartSnapshotsTheInitialMessage() throws {
        var accumulator = MessageAccumulator()
        let message = try accumulator.accumulate(try decode(messageStart))
        XCTAssertEqual(message.id, "msg_1")
        XCTAssertEqual(message.usage.inputTokens, 10)
        XCTAssertEqual(message.content, [])
    }

    func testContentBlockStartAppendsABlock() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        let start = try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":"Hi"}}
        """#)
        let message = try accumulator.accumulate(start)
        XCTAssertEqual(message.content, [.text(TextBlock(text: "Hi"))])
    }

    func testContentBlockDeltaAppendsText() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}
        """#))
        XCTAssertEqual(message.content, [.text(TextBlock(text: "Hello"))])
    }

    func testContentBlockDeltaAppendsCitations() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":"see"}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"citations_delta","citation":
        {"type":"char_location","cited_text":"a","document_index":0,"document_title":null,
        "start_char_index":0,"end_char_index":1,"file_id":null}}}
        """#))
        guard case .text(let block) = message.content[0] else {
            return XCTFail("expected a text block")
        }
        XCTAssertEqual(block.text, "see")
        guard case .charLocation(let citation) = block.citations?.first else {
            return XCTFail("expected a .charLocation citation")
        }
        XCTAssertEqual(citation.citedText, "a")
        XCTAssertEqual(citation.startCharIndex, 0)
        XCTAssertEqual(citation.endCharIndex, 1)
    }

    func testContentBlockDeltaAppendsThinkingAndSetsSignature() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Let me "}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"think."}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"sig-1"}}
        """#))
        guard case .thinking(let block) = message.content[0] else {
            return XCTFail("expected a thinking block")
        }
        XCTAssertEqual(block.thinking, "Let me think.")
        XCTAssertEqual(block.signature, "sig-1")
    }

    func testContentBlockDeltaAccumulatesToolInputAcrossPartialJSONDeltas() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"lookup","input":{}}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"query\""}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":":\"abc\"}"}}
        """#))
        guard case .toolUse(let block) = message.content[0] else {
            return XCTFail("expected a tool_use block")
        }
        XCTAssertEqual(block.id, "toolu_1")
        XCTAssertEqual(block.name, "lookup")
        XCTAssertEqual(block.input, .object(["query": .string("abc")]))
    }

    func testContentBlockDeltaAccumulatesServerToolInput() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"server_tool_use","id":"srvtoolu_1","name":"web_search","input":{}}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"query\":\"swift\"}"}}
        """#))
        guard case .serverToolUse(let block) = message.content[0] else {
            return XCTFail("expected a server_tool_use block")
        }
        XCTAssertEqual(block.input, .object(["query": .string("swift")]))
    }

    func testContentBlockDeltaThrowsForAnIndexThatWasNeverStarted() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        let delta = try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}
        """#)
        XCTAssertThrowsError(try accumulator.accumulate(delta)) { error in
            guard case AnthropicError.responseValidation = error else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
        }
    }

    func testMessageDeltaUnconditionallyOverwritesStopReasonEvenToNil() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        let withStopReason = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":1}}
        """#))
        XCTAssertEqual(withStopReason.stopReason, .endTurn)

        let afterEmptyDelta = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{},"usage":{"output_tokens":2}}
        """#))
        XCTAssertNil(afterEmptyDelta.stopReason)
        XCTAssertEqual(afterEmptyDelta.usage.outputTokens, 2)
    }

    func testMessageDeltaOnlyOverwritesOtherUsageFieldsWhenPresent() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant",
        "model":"claude-opus-5","content":[],"usage":{"input_tokens":10,"output_tokens":0,
        "cache_creation_input_tokens":5}}}
        """#))
        let afterOmitted = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{},"usage":{"output_tokens":1}}
        """#))
        XCTAssertEqual(afterOmitted.usage.cacheCreationInputTokens, 5)
        XCTAssertEqual(afterOmitted.usage.inputTokens, 10)

        let afterProvided = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{},"usage":{"output_tokens":2,"cache_creation_input_tokens":9}}
        """#))
        XCTAssertEqual(afterProvided.usage.cacheCreationInputTokens, 9)
        XCTAssertEqual(afterProvided.usage.outputTokens, 2)
    }

    func testAccumulatesAFullTextMessageEndToEnd() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}
        """#))
        _ = try accumulator.accumulate(try decode(#"{"type":"content_block_stop","index":0}"#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}
        """#))
        let message = try accumulator.accumulate(try decode(#"{"type":"message_stop"}"#))

        XCTAssertEqual(message.content, [.text(TextBlock(text: "Hi"))])
        XCTAssertEqual(message.stopReason, .endTurn)
        XCTAssertEqual(message.usage.outputTokens, 5)
        XCTAssertEqual(try XCTUnwrap(accumulator.snapshot), message)
    }

    func testBuildMessageStreamEventsDerivesATextEventFromATextDelta() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":"Hel"}}
        """#))
        let delta = try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}
        """#)
        let snapshot = try accumulator.accumulate(delta)
        let events = try buildMessageStreamEvents(for: delta, snapshot: snapshot)

        XCTAssertEqual(events.count, 2)
        guard case .contentBlockDelta = events[0] else {
            return XCTFail("expected the raw event to pass through first")
        }
        guard case .text(let textEvent) = events[1] else {
            return XCTFail("expected a derived .text event")
        }
        XCTAssertEqual(textEvent.text, "lo")
        XCTAssertEqual(textEvent.snapshot, "Hello")
    }

    func testBuildMessageStreamEventsDerivesAContentBlockStopWithTheFinalizedBlock() throws {
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}
        """#))
        let stop = try decode(#"{"type":"content_block_stop","index":0}"#)
        let afterStop = try accumulator.accumulate(stop)
        let events = try buildMessageStreamEvents(for: stop, snapshot: afterStop)

        XCTAssertEqual(events.count, 1)
        guard case .contentBlockStop(let stopEvent) = events[0] else {
            return XCTFail("expected a derived .contentBlockStop event")
        }
        XCTAssertEqual(stopEvent.index, 0)
        XCTAssertEqual(stopEvent.contentBlock, .text(TextBlock(text: "Hi")))
    }

    func testBuildMessageStreamEventsThrowsForContentBlockStopAtAnUnstartedIndex() throws {
        var accumulator = MessageAccumulator()
        let snapshot = try accumulator.accumulate(try decode(messageStart))
        let stop = try decode(#"{"type":"content_block_stop","index":0}"#)
        XCTAssertThrowsError(try buildMessageStreamEvents(for: stop, snapshot: snapshot)) { error in
            guard case AnthropicError.responseValidation = error else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
        }
    }
}
