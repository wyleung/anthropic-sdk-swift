import XCTest
@testable import Anthropic

final class MessageStreamIntegrationTests: XCTestCase {
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
        // `.joined` never trails the final element with a separator, so without this the last
        // event's blank-line terminator (the "" above) never actually reaches a "\n" and the
        // event never flushes -- append one more line ending to close it out for real.
        + "\n".data(using: .utf8)!

    private static func readBody(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody { return httpBody }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private func makeStream() async throws -> MessageStream {
        MockURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, Self.sseFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        return try await client.messages.stream(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
        )
    }

    /// Serves exactly `lines` as the SSE body (each `event:`/`data:` line, with `""` as the blank
    /// line that terminates an event).
    private func makeStream(sseLines lines: [String]) async throws -> MessageStream {
        let body = (lines.joined(separator: "\n") + "\n\n").data(using: .utf8)!
        MockURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, body)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        return try await client.messages.stream(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
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

        var passthroughs: [RawMessageStreamEvent] = []
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
        // Previously this threw "Unexpected event order"; Python 1.14.0 / TypeScript 0.134.0 yield it.
        let stream = try await makeStream(sseLines: [
            "event: content_block_delta",
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"early"}}"#,
            "",
        ] + Self.messageStartLines + Self.messageStopLines)

        var events: [MessageStreamEvent] = []
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

        var events: [MessageStreamEvent] = []
        for try await event in await stream.events { events.append(event) }
        XCTAssertEqual(events, [.passthrough(.messageStop(RawMessageStopEvent()))])

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
            // URLSession.bytes(for:) moves the body into httpBodyStream before the protocol sees
            // the request -- httpBody itself is always nil here, unlike for a plain data task.
            capturedBody = Self.readBody(from: request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, Self.sseFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let stream = try await client.messages.stream(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
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
