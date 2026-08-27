import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaSessionsSSETests: XCTestCase {
    private let response = HTTPURLResponse(
        url: URL(string: "https://api.anthropic.com/v1/sessions/sess_1/events/stream")!,
        statusCode: 200, httpVersion: nil, headerFields: nil
    )!

    func testTranslateSkipsPing() throws {
        let sse = ServerSentEvent(event: "ping", data: "{}", raw: [])
        XCTAssertNil(try BetaSessionsSSE.translate(sse, response: response))
    }

    func testTranslateDropsUnrecognizedEventNames() throws {
        let sse = ServerSentEvent(event: "agent.something_new", data: "{}", raw: [])
        XCTAssertNil(try BetaSessionsSSE.translate(sse, response: response))
    }

    func testTranslateDropsEventsWithNoEventName() throws {
        let sse = ServerSentEvent(event: nil, data: "{}", raw: [])
        XCTAssertNil(try BetaSessionsSSE.translate(sse, response: response))
    }

    func testTranslateThrowsOnErrorEvent() {
        let sse = ServerSentEvent(
            event: "error",
            data: #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#,
            raw: []
        )
        XCTAssertThrowsError(try BetaSessionsSSE.translate(sse, response: response)) { error in
            guard let error = error as? AnthropicError else {
                return XCTFail("expected AnthropicError, got \(error)")
            }
            XCTAssertEqual(error.detail?.message, "Overloaded")
            XCTAssertEqual(error.detail?.type, "overloaded_error")
        }
    }

    func testTranslateInjectsTypeFromTheEventNameWhenTheBodyOmitsIt() throws {
        let sse = ServerSentEvent(
            event: "session.status_terminated",
            data: #"{"id":"evt_1","processed_at":"2026-01-01T00:00:00Z"}"#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .sessionStatusTerminated(let terminated) = event else {
            return XCTFail("expected .sessionStatusTerminated, got \(String(describing: event))")
        }
        XCTAssertEqual(terminated.id, "evt_1")
    }

    func testTranslateDecodesAgentToolUse() throws {
        let sse = ServerSentEvent(
            event: "agent.tool_use",
            data: #"""
            {"type":"agent.tool_use","id":"toolu_1","name":"echo","input":{"value":"hi"},
             "processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"allow"}
            """#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .agentToolUse(let toolUse) = event else {
            return XCTFail("expected .agentToolUse, got \(String(describing: event))")
        }
        XCTAssertEqual(toolUse.id, "toolu_1")
        XCTAssertEqual(toolUse.name, "echo")
        XCTAssertEqual(toolUse.input["value"]?.stringValue, "hi")
        XCTAssertEqual(toolUse.evaluatedPermission, .allow)
    }

    func testTranslateDecodesAgentCustomToolUse() throws {
        let sse = ServerSentEvent(
            event: "agent.custom_tool_use",
            data: #"""
            {"type":"agent.custom_tool_use","id":"toolu_2","name":"custom_echo","input":{},
             "processed_at":"2026-01-01T00:00:00Z"}
            """#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .agentCustomToolUse(let toolUse) = event else {
            return XCTFail("expected .agentCustomToolUse, got \(String(describing: event))")
        }
        XCTAssertEqual(toolUse.id, "toolu_2")
        XCTAssertEqual(toolUse.name, "custom_echo")
    }

    func testTranslateDecodesSessionStatusIdleWithEndTurn() throws {
        let sse = ServerSentEvent(
            event: "session.status_idle",
            data: #"""
            {"type":"session.status_idle","id":"evt_3","processed_at":"2026-01-01T00:00:00Z",
             "stop_reason":{"type":"end_turn"}}
            """#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .sessionStatusIdle(let idle) = event else {
            return XCTFail("expected .sessionStatusIdle, got \(String(describing: event))")
        }
        guard case .endTurn = idle.stopReason else {
            return XCTFail("expected .endTurn stop reason, got \(idle.stopReason)")
        }
    }

    func testTranslateDecodesEventStartWithAgentMessagePreview() throws {
        let sse = ServerSentEvent(
            event: "event_start",
            data: #"{"type":"event_start","event":{"type":"agent.message","id":"evt_4"}}"#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .startEvent(let start) = event else {
            return XCTFail("expected .startEvent, got \(String(describing: event))")
        }
        guard case .agentMessage(let preview) = start.event else {
            return XCTFail("expected .agentMessage preview, got \(start.event)")
        }
        XCTAssertEqual(preview.id, "evt_4")
    }

    func testTranslateDecodesEventDelta() throws {
        let sse = ServerSentEvent(
            event: "event_delta",
            data: #"""
            {"type":"event_delta","event_id":"evt_4",
             "delta":{"type":"content_delta","index":0,"content":{"type":"text","text":"Hi"}}}
            """#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .deltaEvent(let delta) = event else {
            return XCTFail("expected .deltaEvent, got \(String(describing: event))")
        }
        XCTAssertEqual(delta.eventId, "evt_4")
        XCTAssertEqual(delta.delta.index, 0)
        XCTAssertEqual(delta.delta.content.text, "Hi")
    }

    func testTranslateDecodesUserToolConfirmation() throws {
        let sse = ServerSentEvent(
            event: "user.tool_confirmation",
            data: #"{"type":"user.tool_confirmation","id":"evt_5","tool_use_id":"toolu_1","result":"allow"}"#,
            raw: []
        )
        let event = try BetaSessionsSSE.translate(sse, response: response)
        guard case .userToolConfirmation(let confirmation) = event else {
            return XCTFail("expected .userToolConfirmation, got \(String(describing: event))")
        }
        XCTAssertEqual(confirmation.toolUseId, "toolu_1")
        XCTAssertEqual(confirmation.result, .allow)
    }
}
