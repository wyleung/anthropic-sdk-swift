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
