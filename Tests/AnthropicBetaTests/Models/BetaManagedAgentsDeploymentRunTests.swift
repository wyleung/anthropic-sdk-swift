import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsDeploymentRunTests: XCTestCase {
    private static let successFixture = """
    {
        "id": "run_01ABC",
        "agent": {"id": "agent_01ABC", "type": "agent", "version": 1},
        "created_at": "2026-01-15T00:00:00Z",
        "deployment_id": "deploy_01ABC",
        "error": null,
        "session_id": "session_01ABC",
        "trigger_context": {"scheduled_at": "2026-01-15T00:00:00Z", "type": "schedule"},
        "type": "deployment_run"
    }
    """.data(using: .utf8)!

    private static let errorFixture = """
    {
        "id": "run_02DEF",
        "agent": {"id": "agent_01ABC", "type": "agent", "version": 1},
        "created_at": "2026-01-15T00:00:00Z",
        "deployment_id": "deploy_01ABC",
        "error": {"message": "the vault was archived", "type": "vault_archived_error"},
        "session_id": null,
        "trigger_context": {"type": "manual"},
        "type": "deployment_run"
    }
    """.data(using: .utf8)!

    func testDecodesSuccessfulScheduledRun() throws {
        let run = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentRun.self, from: Self.successFixture)
        XCTAssertEqual(run.sessionId, "session_01ABC")
        XCTAssertNil(run.error)
        guard case .schedule(let schedule) = run.triggerContext else {
            return XCTFail("Expected a schedule trigger context")
        }
        XCTAssertEqual(schedule.scheduledAt, "2026-01-15T00:00:00Z")
    }

    func testDecodesFailedManualRun() throws {
        let run = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentRun.self, from: Self.errorFixture)
        XCTAssertNil(run.sessionId)
        guard case .manual = run.triggerContext else {
            return XCTFail("Expected a manual trigger context")
        }
        guard case .vaultArchived(let error) = run.error else {
            return XCTFail("Expected a vaultArchived run error")
        }
        XCTAssertEqual(error.message, "the vault was archived")
    }

    func testTriggerContextDecodesUnknownVariant() throws {
        let fixture = """
        {"type": "webhook"}
        """.data(using: .utf8)!
        let context = try HTTPTransport.decoder.decode(BetaManagedAgentsTriggerContext.self, from: fixture)
        guard case .unknown(let type, _) = context else {
            return XCTFail("Expected an unknown trigger context")
        }
        XCTAssertEqual(type, "webhook")
    }

    // MARK: - DeploymentRunError (16 variants + unknown)

    private static let runErrorTypes = [
        "environment_archived_error",
        "agent_archived_error",
        "environment_not_found_error",
        "vault_not_found_error",
        "vault_archived_error",
        "file_not_found_error",
        "memory_store_archived_error",
        "skill_not_found_error",
        "session_resource_not_found_error",
        "workspace_archived_error",
        "organization_disabled_error",
        "session_rate_limited_error",
        "session_creation_rejected_error",
        "unknown_error",
        "self_hosted_resources_unsupported_error",
        "mcp_egress_blocked_error",
    ]

    func testDeploymentRunErrorDecodesAllSixteenVariants() throws {
        for type in Self.runErrorTypes {
            let fixture = "{\"message\": \"boom\", \"type\": \"\(type)\"}".data(using: .utf8)!
            let error = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentRunError.self, from: fixture)
            let encoded = try HTTPTransport.encoder.encode(error)
            let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentRunError.self, from: encoded)
            XCTAssertEqual(error, roundTripped, "round trip failed for \(type)")

            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            XCTAssertEqual(json["type"] as? String, type)
            XCTAssertEqual(json["message"] as? String, "boom")
        }
        XCTAssertEqual(Self.runErrorTypes.count, 16)
    }

    func testDeploymentRunErrorDecodesUnknownVariant() throws {
        let fixture = """
        {"message": "boom", "type": "some_future_error"}
        """.data(using: .utf8)!
        let error = try HTTPTransport.decoder.decode(BetaManagedAgentsDeploymentRunError.self, from: fixture)
        guard case .unknown(let type, _) = error else {
            return XCTFail("Expected an unknown run error")
        }
        XCTAssertEqual(type, "some_future_error")
    }

    func testRunErrorNamesAreSupersetOfPausedReasonErrorNames() {
        let pausedReasonNames: Set<String> = [
            "environment_archived_error", "agent_archived_error", "environment_not_found_error",
            "vault_not_found_error", "file_not_found_error", "session_resource_not_found_error",
            "workspace_archived_error", "organization_disabled_error", "memory_store_archived_error",
            "skill_not_found_error", "vault_archived_error", "unknown_error",
            "self_hosted_resources_unsupported_error", "mcp_egress_blocked_error",
        ]
        XCTAssertTrue(pausedReasonNames.isSubset(of: Set(Self.runErrorTypes)))
        XCTAssertEqual(Set(Self.runErrorTypes).subtracting(pausedReasonNames), [
            "session_rate_limited_error", "session_creation_rejected_error",
        ])
    }
}
