import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMessagesSSETests: XCTestCase {
    private let response = HTTPURLResponse(
        url: URL(string: "https://api.anthropic.com/v1/messages")!,
        statusCode: 200, httpVersion: nil, headerFields: nil
    )!

    func testTranslateSkipsPing() throws {
        let sse = ServerSentEvent(event: "ping", data: "{}", raw: [])
        XCTAssertNil(try BetaMessagesSSE.translate(sse, response: response))
    }

    func testTranslateDropsUnrecognizedEventNames() throws {
        let sse = ServerSentEvent(event: "agent_message_delta", data: "{}", raw: [])
        XCTAssertNil(try BetaMessagesSSE.translate(sse, response: response))
    }

    func testTranslateDropsEventsWithNoEventName() throws {
        let sse = ServerSentEvent(event: nil, data: "{}", raw: [])
        XCTAssertNil(try BetaMessagesSSE.translate(sse, response: response))
    }

    func testTranslateThrowsOnErrorEvent() {
        let sse = ServerSentEvent(
            event: "error",
            data: #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#,
            raw: []
        )
        XCTAssertThrowsError(try BetaMessagesSSE.translate(sse, response: response)) { error in
            guard let error = error as? AnthropicError else {
                return XCTFail("expected AnthropicError, got \(error)")
            }
            XCTAssertEqual(error.detail?.message, "Overloaded")
            XCTAssertEqual(error.detail?.type, "overloaded_error")
        }
    }

    func testTranslateInjectsTypeFromTheEventNameWhenTheBodyOmitsIt() throws {
        let sse = ServerSentEvent(event: "message_stop", data: "{}", raw: [])
        let event = try BetaMessagesSSE.translate(sse, response: response)
        guard case .messageStop = event else {
            return XCTFail("expected .messageStop, got \(String(describing: event))")
        }
    }

    func testTranslateDecodesAContentBlockDelta() throws {
        let sse = ServerSentEvent(
            event: "content_block_delta",
            data: #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}"#,
            raw: []
        )
        let event = try BetaMessagesSSE.translate(sse, response: response)
        guard case .contentBlockDelta(let delta) = event else {
            return XCTFail("expected .contentBlockDelta, got \(String(describing: event))")
        }
        XCTAssertEqual(delta.index, 0)
        guard case .text(let textDelta) = delta.delta else {
            return XCTFail("expected a .text delta")
        }
        XCTAssertEqual(textDelta.text, "Hi")
    }
}
