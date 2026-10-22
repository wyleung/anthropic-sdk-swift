import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Managed Agents session additions: workflow-run events, repository errors, refusals, and thread fields.
final class BetaManagedAgentsSessionAdditionsTests: XCTestCase {
    private func event(_ json: String) throws -> BetaManagedAgentsSessionEvent {
        try HTTPTransport.decoder.decode(BetaManagedAgentsSessionEvent.self, from: Data(json.utf8))
    }

    // MARK: - workflow run events

    func testWorkflowRunCreatedDecodesItsPhases() throws {
        guard case .workflowRunCreated(let created) = try event("""
        {"id": "e1", "type": "workflow_run.created", "processed_at": "2026-10-10T00:00:00Z", "name": "Release",
         "description": "Cut a release", "workflow_run_id": "wfr_1",
         "phases": [{"id": "p1", "name": "Plan", "description": "decide"}, {"id": "p2", "name": "Ship"}]}
        """) else { return XCTFail("expected workflowRunCreated") }
        XCTAssertEqual(created.workflowRunId, "wfr_1")
        XCTAssertEqual(created.phases.map(\.name), ["Plan", "Ship"])
        XCTAssertEqual(created.phases[0].description, "decide")
        XCTAssertNil(created.phases[1].description)
    }

    func testWorkflowRunEndedCarriesEachKindOfResult() throws {
        func result(_ json: String) throws -> BetaManagedAgentsWorkflowRunResult {
            guard case .workflowRunStatusEnded(let ended) = try event("""
            {"id": "e", "type": "workflow_run.status_ended", "processed_at": "t", "workflow_run_id": "wfr_1", "result": \(json)}
            """) else { throw XCTSkip("not an ended event") }
            return ended.result
        }
        guard case .completed = try result(#"{"type": "completed"}"#) else { return XCTFail("completed") }
        guard case .stopped = try result(#"{"type": "stopped"}"#) else { return XCTFail("stopped") }
        guard case .error(let failed) = try result(#"{"type": "error", "error": {"type": "timeout_error", "message": "too slow"}}"#),
              case .timeout(let timeout) = failed.error else { return XCTFail("error/timeout") }
        XCTAssertEqual(timeout.message, "too slow")
        guard case .unknown(let type, _) = try result(#"{"type": "paused"}"#) else { return XCTFail("unknown") }
        XCTAssertEqual(type, "paused")
    }

    func testEveryWorkflowRunErrorShapeDecodesAndANewOneDegrades() throws {
        func error(_ type: String) throws -> BetaManagedAgentsWorkflowRunError {
            try HTTPTransport.decoder.decode(BetaManagedAgentsWorkflowRunError.self, from: Data(#"{"type": "\#(type)", "message": "m"}"#.utf8))
        }
        guard case .timeout = try error("timeout_error"), case .program = try error("program_error"),
              case .unknownError = try error("unknown_error"), case .threadLimit = try error("thread_limit_error"),
              case .maxWorkflowRuns = try error("max_workflow_runs_error") else { return XCTFail("a known error mis-decoded") }
        guard case .unknown(let type, _) = try error("quota_error") else { return XCTFail("expected .unknown") }
        XCTAssertEqual(type, "quota_error")
    }

    func testWorkflowRunErrorEventDoesNotRequireARunId() throws {
        guard case .workflowRunError(let failed) = try event("""
        {"id": "e", "type": "workflow_run.error", "processed_at": "t", "error": {"type": "max_workflow_runs_error", "message": "limit"}}
        """) else { return XCTFail("expected workflowRunError") }
        XCTAssertNil(failed.workflowRunId)
    }

    func testPhaseEventsLinkEndBackToStart() throws {
        guard case .workflowRunPhaseEnded(let ended) = try event("""
        {"id": "e3", "type": "workflow_run.phase_ended", "processed_at": "t", "phase_started_id": "e2",
         "workflow_run_id": "wfr_1", "workflow_run_phase_id": "p1"}
        """) else { return XCTFail("expected phase_ended") }
        XCTAssertEqual(ended.phaseStartedId, "e2")
        XCTAssertEqual(ended.workflowRunPhaseId, "p1")
    }

    // MARK: - repository errors

    func testEveryRepositoryErrorDecodesWithItsRetryStatus() throws {
        let cases: [(String, (BetaManagedAgentsSessionEventError) -> Bool)] = [
            ("repository_authentication_error", { if case .repositoryAuthentication = $0 { return true } else { return false } }),
            ("repository_forbidden_error", { if case .repositoryForbidden = $0 { return true } else { return false } }),
            ("repository_not_found_error", { if case .repositoryNotFound = $0 { return true } else { return false } }),
            ("repository_checkout_error", { if case .repositoryCheckout = $0 { return true } else { return false } }),
            ("repository_clone_error", { if case .repositoryClone = $0 { return true } else { return false } }),
        ]
        for (type, isExpected) in cases {
            let error = try HTTPTransport.decoder.decode(BetaManagedAgentsSessionEventError.self, from: Data("""
            {"type": "\(type)", "message": "nope", "repository_url": "https://github.com/o/r", "retry_status": {"type": "terminal"}}
            """.utf8))
            XCTAssertTrue(isExpected(error), "\(type) decoded as \(error)")
        }
    }

    func testRepositoryErrorUrlIsOptional() throws {
        guard case .repositoryClone(let clone) = try HTTPTransport.decoder.decode(BetaManagedAgentsSessionEventError.self, from: Data("""
        {"type": "repository_clone_error", "message": "m", "retry_status": {"type": "exhausted"}}
        """.utf8)) else { return XCTFail("expected clone") }
        XCTAssertNil(clone.repositoryUrl)
    }

    // MARK: - refusal

    func testIdleWithARefusalCarriesTheStopDetails() throws {
        guard case .sessionStatusIdle(let idle) = try event("""
        {"id": "e", "type": "session.status_idle", "processed_at": "t", "stop_reason": {"type": "refusal"},
         "stop_details": {"type": "refusal", "category": "cyber", "explanation": "declined"}}
        """) else { return XCTFail("expected idle") }
        guard case .refusal = idle.stopReason else { return XCTFail("expected .refusal, got \(idle.stopReason)") }
        XCTAssertEqual(idle.stopDetails?.category, .cyber)
        XCTAssertEqual(idle.stopDetails?.explanation, "declined")
    }

    func testThreadIdleWithARefusalCarriesTheStopDetailsToo() throws {
        guard case .sessionThreadStatusIdle(let idle) = try event("""
        {"id": "e", "type": "session.thread_status_idle", "processed_at": "t", "agent_name": "a", "session_thread_id": "th_1",
         "stop_reason": {"type": "refusal"}, "stop_details": {"type": "refusal"}}
        """) else { return XCTFail("expected thread idle") }
        XCTAssertNotNil(idle.stopDetails)
        XCTAssertNil(idle.stopDetails?.category, "category is optional")
    }

    func testAnIdleWithoutStopDetailsStillDecodes() throws {
        guard case .sessionStatusIdle(let idle) = try event(#"{"id": "e", "type": "session.status_idle", "processed_at": "t", "stop_reason": {"type": "end_turn"}}"#)
        else { return XCTFail("expected idle") }
        XCTAssertNil(idle.stopDetails)
    }

    func testARefusalEndsTheTurnSoTheIdleWatchdogArmsOnIt() {
        // Upstream's rule: every stop reason but `requires_action` ends the turn.
        XCTAssertTrue(SessionToolRunner.endsTurn(.refusal(BetaManagedAgentsSessionRefusal())))
    }

    // MARK: - thread fields

    func testThreadAndThreadCreatedEventCarryTheWorkflowRunId() throws {
        guard case .sessionThreadCreated(let created) = try event("""
        {"id": "e", "type": "session.thread_created", "processed_at": "t", "agent_name": "a", "session_thread_id": "th_1", "workflow_run_id": "wfr_9"}
        """) else { return XCTFail("expected thread_created") }
        XCTAssertEqual(created.workflowRunId, "wfr_9")
        guard case .sessionThreadCreated(let plain) = try event("""
        {"id": "e", "type": "session.thread_created", "processed_at": "t", "agent_name": "a", "session_thread_id": "th_1"}
        """) else { return XCTFail("expected thread_created") }
        XCTAssertNil(plain.workflowRunId)
    }
}
