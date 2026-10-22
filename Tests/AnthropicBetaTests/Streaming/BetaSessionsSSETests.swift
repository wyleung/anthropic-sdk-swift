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

    func testTranslateSurfacesUnrecognizedEventNamesAsUnknownInsteadOfDroppingThem() throws {
        // A hard-coded allowlist used to swallow every event type added after this port; Python 1.16.0 and
        // TypeScript 0.136.0 now yield them.
        let sse = ServerSentEvent(event: "agent.something_new", data: #"{"note": "hi"}"#, raw: [])
        guard case .unknown(let type, let raw) = try BetaSessionsSSE.translate(sse, response: response) else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(type, "agent.something_new")
        XCTAssertEqual(raw["note"]?.stringValue, "hi")
    }

    func testTranslateHandsOverANonJSONPayloadOfAnUnrecognizedEventVerbatim() throws {
        let sse = ServerSentEvent(event: "future.event", data: "not json", raw: [])
        XCTAssertEqual(
            try BetaSessionsSSE.translate(sse, response: response), .unknown(type: "future.event", raw: .string("not json"))
        )
    }

    func testTranslateStillThrowsOnAMalformedPayloadUnderAKnownEventName() {
        let sse = ServerSentEvent(event: "agent.tool_use", data: "not json", raw: [])
        XCTAssertThrowsError(try BetaSessionsSSE.translate(sse, response: response))
    }

    func testTranslateSkipsEventsWithNoData() throws {
        XCTAssertNil(try BetaSessionsSSE.translate(ServerSentEvent(event: "agent.tool_use", data: "", raw: []), response: response))
        XCTAssertNil(try BetaSessionsSSE.translate(ServerSentEvent(event: "future.event", data: "", raw: []), response: response))
    }

    func testEveryWorkflowRunEventNameReachesTheStreamAsATypedEvent() throws {
        // The regression this guards: with the old allowlist, none of these were delivered at all.
        let names = [
            "workflow_run.created", "workflow_run.status_running", "workflow_run.status_idle", "workflow_run.status_ended",
            "workflow_run.error", "workflow_run.phase_started", "workflow_run.phase_ended",
        ]
        let bodies = [
            #"{"id":"e","processed_at":"t","name":"wf","phases":[{"id":"p1","name":"Plan"}],"workflow_run_id":"wfr_1"}"#,
            #"{"id":"e","processed_at":"t","workflow_run_id":"wfr_1"}"#,
            #"{"id":"e","processed_at":"t","workflow_run_id":"wfr_1"}"#,
            #"{"id":"e","processed_at":"t","workflow_run_id":"wfr_1","result":{"type":"completed"}}"#,
            #"{"id":"e","processed_at":"t","error":{"type":"program_error","message":"boom"}}"#,
            #"{"id":"e","processed_at":"t","workflow_run_id":"wfr_1","workflow_run_phase_id":"p1"}"#,
            #"{"id":"e","processed_at":"t","phase_started_id":"e0","workflow_run_id":"wfr_1","workflow_run_phase_id":"p1"}"#,
        ]
        for (name, body) in zip(names, bodies) {
            let event = try XCTUnwrap(try BetaSessionsSSE.translate(ServerSentEvent(event: name, data: body, raw: []), response: response), name)
            if case .unknown = event { XCTFail("\(name) fell through to .unknown") }
        }
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
