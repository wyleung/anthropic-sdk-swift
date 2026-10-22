import XCTest
@testable import Anthropic

final class MessagesSSETests: XCTestCase {
    private let response = HTTPURLResponse(
        url: URL(string: "https://api.anthropic.com/v1/messages")!,
        statusCode: 200, httpVersion: nil, headerFields: nil
    )!

    func testTranslateSkipsPing() throws {
        let sse = ServerSentEvent(event: "ping", data: "{}", raw: [])
        XCTAssertNil(try MessagesSSE.translate(sse, response: response))
    }

    func testTranslateSurfacesUnrecognizedEventNamesAsUnknownInsteadOfDroppingThem() throws {
        // Python 1.16.0 / TypeScript 0.136.0: unrecognized names are yielded, not dropped. The body
        // omits `type`, so it is injected from the event name just like for the known events.
        let sse = ServerSentEvent(event: "agent_message_delta", data: #"{"text":"hi"}"#, raw: [])
        let event = try MessagesSSE.translate(sse, response: response)
        guard case .unknown(let type, let raw) = event else {
            return XCTFail("expected .unknown, got \(String(describing: event))")
        }
        XCTAssertEqual(type, "agent_message_delta")
        XCTAssertEqual(raw["text"]?.stringValue, "hi")
        XCTAssertEqual(raw["type"]?.stringValue, "agent_message_delta")
    }

    func testTranslateKeepsTheTypeAUnknownEventCarriesRatherThanOverwritingItWithTheEventName() throws {
        let sse = ServerSentEvent(event: "wrapper", data: #"{"type":"inner_type"}"#, raw: [])
        guard case .unknown(let type, _) = try MessagesSSE.translate(sse, response: response) else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(type, "inner_type")
    }

    func testTranslateHandsOverANonJSONPayloadOfAnUnrecognizedEventVerbatimInsteadOfThrowing() throws {
        let sse = ServerSentEvent(event: "future_event", data: "not json at all", raw: [])
        let event = try MessagesSSE.translate(sse, response: response)
        XCTAssertEqual(event, .unknown(type: "future_event", raw: .string("not json at all")))
    }

    func testTranslateStillThrowsOnAMalformedPayloadUnderAKnownEventName() {
        let sse = ServerSentEvent(event: "message_start", data: "not json at all", raw: [])
        XCTAssertThrowsError(try MessagesSSE.translate(sse, response: response))
    }

    func testTranslateSkipsEventsWithNoData() throws {
        // Python: `if not sse.data: continue` -- applies to known names too, which used to hit a
        // JSON parse error on the empty string.
        XCTAssertNil(try MessagesSSE.translate(ServerSentEvent(event: "message_stop", data: "", raw: []), response: response))
        XCTAssertNil(try MessagesSSE.translate(ServerSentEvent(event: "future_event", data: "", raw: []), response: response))
    }

    func testUnknownEventPayloadKeepsWireKeysUntouchedNestedAndTopLevel() throws {
        // `.unknown`'s `raw` is the only way a caller can read a type this port doesn't model, so it
        // must stay faithful to the wire -- `.convertFromSnakeCase` must not rewrite its keys.
        let sse = ServerSentEvent(event: "future_event", data: #"{"tool_use_id":"t1","nested":{"some_key":1}}"#, raw: [])
        guard case .unknown(_, let raw) = try MessagesSSE.translate(sse, response: response) else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(raw["tool_use_id"]?.stringValue, "t1")
        XCTAssertEqual(raw["nested"]?["some_key"], .number(1))
        XCTAssertNil(raw["toolUseId"])
    }

    func testTranslateDropsEventsWithNoEventName() throws {
        let sse = ServerSentEvent(event: nil, data: "{}", raw: [])
        XCTAssertNil(try MessagesSSE.translate(sse, response: response))
    }

    func testTranslateThrowsOnErrorEvent() {
        let sse = ServerSentEvent(
            event: "error",
            data: #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#,
            raw: []
        )
        XCTAssertThrowsError(try MessagesSSE.translate(sse, response: response)) { error in
            guard let error = error as? AnthropicError else {
                return XCTFail("expected AnthropicError, got \(error)")
            }
            XCTAssertEqual(error.detail?.message, "Overloaded")
            XCTAssertEqual(error.detail?.type, "overloaded_error")
        }
    }

    func testTranslateInjectsTypeFromTheEventNameWhenTheBodyOmitsIt() throws {
        let sse = ServerSentEvent(event: "message_stop", data: "{}", raw: [])
        let event = try MessagesSSE.translate(sse, response: response)
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
        let event = try MessagesSSE.translate(sse, response: response)
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
