import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMessageAccumulatorTests: XCTestCase {
    private func decode(_ json: String) throws -> BetaRawMessageStreamEvent {
        try HTTPTransport.decoder.decode(BetaRawMessageStreamEvent.self, from: Data(json.utf8))
    }

    private let messageStart = #"""
    {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant",
    "model":"claude-opus-5","content":[],"usage":{"input_tokens":10,"output_tokens":0}}}
    """#

    func testAccumulateThrowsIfTheStreamDoesNotBeginWithMessageStart() throws {
        var accumulator = BetaMessageAccumulator()
        let stop = try decode(#"{"type":"message_stop"}"#)
        XCTAssertThrowsError(try accumulator.accumulate(stop)) { error in
            guard case AnthropicError.responseValidation = error else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
        }
    }

    func testMessageStartSnapshotsTheInitialMessage() throws {
        var accumulator = BetaMessageAccumulator()
        let message = try accumulator.accumulate(try decode(messageStart))
        XCTAssertEqual(message.id, "msg_1")
        XCTAssertEqual(message.usage.inputTokens, 10)
        XCTAssertEqual(message.content, [])
    }

    func testContentBlockStartAppendsABlock() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        let start = try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":"Hi"}}
        """#)
        let message = try accumulator.accumulate(start)
        XCTAssertEqual(message.content, [.text(TextBlock(text: "Hi"))])
    }

    func testContentBlockDeltaAppendsText() throws {
        var accumulator = BetaMessageAccumulator()
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

    func testContentBlockDeltaAccumulatesToolInputAcrossPartialJSONDeltas() throws {
        var accumulator = BetaMessageAccumulator()
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
        XCTAssertEqual(block.input, .object(["query": .string("abc")]))
    }

    func testContentBlockDeltaAccumulatesMCPToolInput() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":
        {"type":"mcp_tool_use","id":"mcptoolu_1","name":"search","server_name":"docs","input":{}}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"q\":\"swift\"}"}}
        """#))
        guard case .mcpToolUse(let block) = message.content[0] else {
            return XCTFail("expected an mcp_tool_use block")
        }
        XCTAssertEqual(block.serverName, "docs")
        XCTAssertEqual(block.input, ["q": .string("swift")])
    }

    func testContentBlockDeltaReplacesCompactionContent() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"compaction","content":"partial"}}
        """#))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"compaction_delta","content":"full summary"}}
        """#))
        guard case .compaction(let block) = message.content[0] else {
            return XCTFail("expected a compaction block")
        }
        XCTAssertEqual(block.content, "full summary")
    }

    func testMessageDeltaOverwritesStopReasonWithABetaOnlyValue() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{"stop_reason":"compaction"},"usage":{"output_tokens":1}}
        """#))
        XCTAssertEqual(message.stopReason, .compaction)
    }

    func testMessageDeltaPropagatesContainer() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        let message = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{"container":{"id":"cont_1","expires_at":"2026-01-01T00:00:00Z"}},
        "usage":{"output_tokens":1}}
        """#))
        XCTAssertEqual(message.container?.id, "cont_1")
    }

    func testAccumulatesAFullTextMessageEndToEnd() throws {
        var accumulator = BetaMessageAccumulator()
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

    func testBuildBetaMessageStreamEventsDerivesATextEventFromATextDelta() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":"Hel"}}
        """#))
        let delta = try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}
        """#)
        let snapshot = try accumulator.accumulate(delta)
        let events = try buildBetaMessageStreamEvents(for: delta, snapshot: snapshot)

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

    func testBuildBetaMessageStreamEventsDerivesAContentBlockStopWithTheFinalizedBlock() throws {
        var accumulator = BetaMessageAccumulator()
        _ = try accumulator.accumulate(try decode(messageStart))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}
        """#))
        let stop = try decode(#"{"type":"content_block_stop","index":0}"#)
        let afterStop = try accumulator.accumulate(stop)
        let events = try buildBetaMessageStreamEvents(for: stop, snapshot: afterStop)

        XCTAssertEqual(events.count, 1)
        guard case .contentBlockStop(let stopEvent) = events[0] else {
            return XCTFail("expected a derived .contentBlockStop event")
        }
        XCTAssertEqual(stopEvent.index, 0)
        XCTAssertEqual(stopEvent.contentBlock, .text(TextBlock(text: "Hi")))
    }
}
