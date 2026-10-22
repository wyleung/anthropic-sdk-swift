import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMessageStreamIntegrationTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let sseFixture: Data = [
        "event: message_start",
        #"data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5","content":[],"usage":{"input_tokens":10,"output_tokens":0}}}"#,
        "",
        "event: content_block_start",
        #"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
        "",
        "event: content_block_delta",
        #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#,
        "",
        "event: content_block_delta",
        #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}"#,
        "",
        "event: content_block_stop",
        #"data: {"type":"content_block_stop","index":0}"#,
        "",
        "event: message_delta",
        #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}"#,
        "",
        "event: message_stop",
        #"data: {"type":"message_stop"}"#,
        "",
    ].joined(separator: "\n").data(using: .utf8)!
        // Same fixup as GA's MessageStreamIntegrationTests: `.joined` doesn't trail the final
        // element with a separator, so the last event's blank-line terminator never reaches a
        // "\n" without this -- append one more to actually flush it.
        + "\n".data(using: .utf8)!

    private func makeStream() async throws -> BetaMessageStream {
        MockURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, Self.sseFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        return try await client.beta.messages.stream(
            BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
        )
    }

    private func makeStream(sseLines lines: [String]) async throws -> BetaMessageStream {
        let body = (lines.joined(separator: "\n") + "\n\n").data(using: .utf8)!
        MockURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, body)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        return try await client.beta.messages.stream(
            BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
        )
    }

    private static let messageStartLines = [
        "event: message_start",
        #"data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5","content":[],"usage":{"input_tokens":1,"output_tokens":0}}}"#,
        "",
    ]
    private static let messageStopLines = ["event: message_stop", #"data: {"type":"message_stop"}"#, ""]

    func testUnrecognizedEventMidStreamIsPassedThroughAndDoesNotDisturbTheMessage() async throws {
        let stream = try await makeStream(sseLines: Self.messageStartLines + [
            "event: some_future_event",
            #"data: {"type":"some_future_event","detail":"x"}"#,
            "",
        ] + Self.messageStopLines)

        var passthroughs: [BetaRawMessageStreamEvent] = []
        for try await event in await stream.events {
            if case .passthrough(let raw) = event { passthroughs.append(raw) }
        }
        XCTAssertEqual(passthroughs.count, 1)
        guard case .unknown(let type, let raw) = passthroughs.first else {
            return XCTFail("expected .unknown, got \(String(describing: passthroughs.first))")
        }
        XCTAssertEqual(type, "some_future_event")
        XCTAssertEqual(raw["detail"]?.stringValue, "x")
        let message = try await stream.finalMessage()
        XCTAssertEqual(message.id, "msg_1")
    }

    func testEventBeforeMessageStartIsPassedThroughInsteadOfFailingTheStream() async throws {
        let stream = try await makeStream(sseLines: [
            "event: content_block_delta",
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"early"}}"#,
            "",
        ] + Self.messageStartLines + Self.messageStopLines)

        var events: [BetaMessageStreamEvent] = []
        for try await event in await stream.events { events.append(event) }

        guard case .passthrough(.contentBlockDelta(let early)) = events.first else {
            return XCTFail("expected the early delta first as .passthrough, got \(String(describing: events.first))")
        }
        XCTAssertEqual(early.index, 0)
        XCTAssertEqual(events.count, 3, "passthrough + message_start + message_stop")
        let message = try await stream.finalMessage()
        XCTAssertEqual(message.id, "msg_1")
        XCTAssertTrue(message.content.isEmpty, "the pre-start delta must not have been folded into the snapshot")
    }

    func testStreamWithNoMessageStartStillFailsFinalMessageEvenThoughItsEventsPassedThrough() async throws {
        let stream = try await makeStream(sseLines: Self.messageStopLines)
        var count = 0
        for try await event in await stream.events {
            guard case .passthrough(.messageStop) = event else { return XCTFail("unexpected \(event)") }
            count += 1
        }
        XCTAssertEqual(count, 1)
        do {
            _ = try await stream.finalMessage()
            XCTFail("expected finalMessage() to throw")
        } catch AnthropicError.responseValidation(let message, _) {
            XCTAssertTrue(message.contains("before a message_start"), message)
        }
    }

    func testStreamInjectsStreamTrueIntoTheRequestBody() async throws {
        var capturedBody: Data?
        MockURLProtocol.responder = { request in
            capturedBody = bodyData(from: request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, Self.sseFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let stream = try await client.beta.messages.stream(
            BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
        )
        _ = try await stream.finalMessage()

        let body = try XCTUnwrap(capturedBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["stream"] as? Bool, true)
    }

    func testFinalMessageReflectsTheFullyAccumulatedStream() async throws {
        let stream = try await makeStream()
        let message = try await stream.finalMessage()

        XCTAssertEqual(message.id, "msg_1")
        XCTAssertEqual(message.stopReason, .endTurn)
        XCTAssertEqual(message.usage.outputTokens, 5)
        guard case .text(let block) = message.content.first else {
            return XCTFail("expected a text block")
        }
        XCTAssertEqual(block.text, "Hello world")
    }

    func testTextStreamYieldsIncrementalText() async throws {
        let stream = try await makeStream()
        var pieces: [String] = []
        for try await piece in await stream.textStream {
            pieces.append(piece)
        }
        XCTAssertEqual(pieces, ["Hello", " world"])
    }

    func testEventsCanBeSubscribedToMultipleTimesIndependently() async throws {
        let stream = try await makeStream()

        @Sendable func countEvents() async throws -> Int {
            var count = 0
            for try await _ in await stream.events { count += 1 }
            return count
        }

        async let firstCount = countEvents()
        async let secondCount = countEvents()
        let (first, second) = try await (firstCount, secondCount)

        XCTAssertEqual(first, second)
        XCTAssertGreaterThan(first, 0)
    }
}
