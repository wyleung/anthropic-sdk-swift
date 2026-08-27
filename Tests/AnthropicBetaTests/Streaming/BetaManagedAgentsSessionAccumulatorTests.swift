import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsSessionAccumulatorTests: XCTestCase {
    private func startEvent(_ preview: BetaManagedAgentsStartEventPreview) -> BetaManagedAgentsStreamSessionEvents {
        .startEvent(BetaManagedAgentsStartEvent(event: preview))
    }

    private func deltaEvent(
        eventId: String, index: Int?, text: String
    ) -> BetaManagedAgentsStreamSessionEvents {
        .deltaEvent(
            BetaManagedAgentsDeltaEvent(
                delta: BetaManagedAgentsDeltaContent(content: BetaManagedAgentsTextBlock(text: text), index: index),
                eventId: eventId
            )
        )
    }

    func testEventStartWithAgentMessagePreviewOpensAnEmptySnapshot() throws {
        let event = startEvent(.agentMessage(BetaManagedAgentsAgentMessagePreview(id: "evt_1")))

        let accumulated = try accumulateManagedAgentsEvent(nil, event)

        let snapshot = try XCTUnwrap(accumulated)
        XCTAssertEqual(snapshot.id, "evt_1")
        XCTAssertEqual(snapshot.content, [])
        XCTAssertEqual(snapshot.processedAt, "1970-01-01T00:00:00Z")
    }

    func testEventStartWithAgentThinkingPreviewPassesThroughUnchanged() throws {
        let existing = BetaManagedAgentsAgentMessageEvent(content: [], id: "evt_1", processedAt: "2026-01-01T00:00:00Z")
        let event = startEvent(.agentThinking(BetaManagedAgentsAgentThinkingPreview(id: "evt_2")))

        let accumulated = try accumulateManagedAgentsEvent(existing, event)

        XCTAssertEqual(accumulated, existing)
    }

    func testEventStartWithUnknownPreviewPassesThroughUnchanged() throws {
        let existing = BetaManagedAgentsAgentMessageEvent(content: [], id: "evt_1", processedAt: "2026-01-01T00:00:00Z")
        let event = startEvent(.unknown(type: "agent.something_new", raw: .object(["type": .string("agent.something_new")])))

        let accumulated = try accumulateManagedAgentsEvent(existing, event)

        XCTAssertEqual(accumulated, existing)
    }

    func testBufferedFinalAgentMessageReplacesTheAccumulatedSnapshot() throws {
        let preview = BetaManagedAgentsAgentMessageEvent(
            content: [.text(BetaManagedAgentsTextBlock(text: "partial"))], id: "evt_1",
            processedAt: "1970-01-01T00:00:00Z"
        )
        let final = BetaManagedAgentsAgentMessageEvent(
            content: [.text(BetaManagedAgentsTextBlock(text: "the full message"))], id: "evt_1",
            processedAt: "2026-01-01T00:00:00Z"
        )

        let accumulated = try accumulateManagedAgentsEvent(preview, .agentMessage(final))

        XCTAssertEqual(accumulated, final)
    }

    func testDeltaAppendsANewContentEntryAtTheNextIndex() throws {
        let snapshot = BetaManagedAgentsAgentMessageEvent(content: [], id: "evt_1", processedAt: "1970-01-01T00:00:00Z")

        let accumulated = try accumulateManagedAgentsEvent(snapshot, deltaEvent(eventId: "evt_1", index: 0, text: "Hi"))

        let result = try XCTUnwrap(accumulated)
        guard case .text(let block) = result.content.first else {
            return XCTFail("expected a .text content entry")
        }
        XCTAssertEqual(block.text, "Hi")
        XCTAssertEqual(result.id, "evt_1")
    }

    func testDeltaWithNoIndexDefaultsToZero() throws {
        let snapshot = BetaManagedAgentsAgentMessageEvent(content: [], id: "evt_1", processedAt: "1970-01-01T00:00:00Z")

        let accumulated = try accumulateManagedAgentsEvent(snapshot, deltaEvent(eventId: "evt_1", index: nil, text: "Hi"))

        let result = try XCTUnwrap(accumulated)
        guard case .text(let block) = result.content.first else {
            return XCTFail("expected a .text content entry")
        }
        XCTAssertEqual(block.text, "Hi")
    }

    func testDeltaConcatenatesIntoAnExistingTextEntry() throws {
        let snapshot = BetaManagedAgentsAgentMessageEvent(
            content: [.text(BetaManagedAgentsTextBlock(text: "Hello"))], id: "evt_1",
            processedAt: "1970-01-01T00:00:00Z"
        )

        let accumulated = try accumulateManagedAgentsEvent(snapshot, deltaEvent(eventId: "evt_1", index: 0, text: " world"))

        let result = try XCTUnwrap(accumulated)
        guard case .text(let block) = result.content.first else {
            return XCTFail("expected a .text content entry")
        }
        XCTAssertEqual(block.text, "Hello world")
        XCTAssertEqual(result.content.count, 1)
    }

    func testDeltaLeavesANonTextExistingEntryUnchanged() throws {
        let snapshot = BetaManagedAgentsAgentMessageEvent(
            content: [.redacted(BetaManagedAgentsRedactedBlock())], id: "evt_1",
            processedAt: "1970-01-01T00:00:00Z"
        )

        let accumulated = try accumulateManagedAgentsEvent(snapshot, deltaEvent(eventId: "evt_1", index: 0, text: "ignored"))

        let result = try XCTUnwrap(accumulated)
        guard case .redacted = result.content.first else {
            return XCTFail("expected the existing .redacted entry to pass through unchanged")
        }
        XCTAssertEqual(result.content.count, 1)
    }

    func testDeltaThrowsWhenAccumulatedIsNil() {
        XCTAssertThrowsError(
            try accumulateManagedAgentsEvent(nil, deltaEvent(eventId: "evt_1", index: 0, text: "Hi"))
        ) { error in
            guard case .responseValidation(let message, _) = error as? AnthropicError else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
            XCTAssertTrue(message.contains("evt_1"))
            XCTAssertTrue(message.contains("before its event_start"))
        }
    }

    func testDeltaThrowsWhenIndexIsBeyondTheEndOfContent() {
        let snapshot = BetaManagedAgentsAgentMessageEvent(content: [], id: "evt_1", processedAt: "1970-01-01T00:00:00Z")

        XCTAssertThrowsError(
            try accumulateManagedAgentsEvent(snapshot, deltaEvent(eventId: "evt_1", index: 5, text: "Hi"))
        ) { error in
            guard case .responseValidation(let message, _) = error as? AnthropicError else {
                return XCTFail("expected .responseValidation, got \(error)")
            }
            XCTAssertTrue(message.contains("beyond the end of content"))
        }
    }

    func testUnrelatedEventPassesTheAccumulatedSnapshotThroughUnchanged() throws {
        let snapshot = BetaManagedAgentsAgentMessageEvent(content: [], id: "evt_1", processedAt: "1970-01-01T00:00:00Z")
        let unrelated = BetaManagedAgentsStreamSessionEvents.userMessage(
            BetaManagedAgentsUserMessageEvent(content: [], id: "evt_9")
        )

        let accumulated = try accumulateManagedAgentsEvent(snapshot, unrelated)

        XCTAssertEqual(accumulated, snapshot)
    }
}
