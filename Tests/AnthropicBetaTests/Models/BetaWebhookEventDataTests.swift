import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaWebhookEventDataTests: XCTestCase {
    func testDecodesBaseShapeVariant() throws {
        let fixture = """
        {"id": "sesn_01ABC", "organization_id": "org_01ABC", "type": "session.status_idled", "workspace_id": "wrkspc_01ABC"}
        """.data(using: .utf8)!
        let data = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: fixture)
        guard case .sessionStatusIdled(let event) = data else {
            return XCTFail("expected .sessionStatusIdled, got \(data)")
        }
        XCTAssertEqual(event.id, "sesn_01ABC")
        XCTAssertEqual(event.organizationId, "org_01ABC")
        XCTAssertEqual(event.workspaceId, "wrkspc_01ABC")
    }

    func testDecodesSessionThreadVariantWithExtraField() throws {
        let fixture = """
        {"id": "sesn_01ABC", "organization_id": "org_01ABC", "session_thread_id": "sthr_01XYZ",
         "type": "session.thread_created", "workspace_id": "wrkspc_01ABC"}
        """.data(using: .utf8)!
        let data = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: fixture)
        guard case .sessionThreadCreated(let event) = data else {
            return XCTFail("expected .sessionThreadCreated, got \(data)")
        }
        XCTAssertEqual(event.sessionThreadId, "sthr_01XYZ")
    }

    func testDecodesVaultCredentialVariantWithExtraField() throws {
        let fixture = """
        {"id": "vcrd_01ABC", "organization_id": "org_01ABC", "type": "vault_credential.refresh_failed",
         "vault_id": "vault_01XYZ", "workspace_id": "wrkspc_01ABC"}
        """.data(using: .utf8)!
        let data = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: fixture)
        guard case .vaultCredentialRefreshFailed(let event) = data else {
            return XCTFail("expected .vaultCredentialRefreshFailed, got \(data)")
        }
        XCTAssertEqual(event.vaultId, "vault_01XYZ")
    }

    func testDecodesAgentDeploymentEnvironmentMemoryStoreVaultVariants() throws {
        let cases:
            [(json: String, verify: (BetaWebhookEventData) -> Void)] = [
                (
                    """
                    {"id": "agt_1", "organization_id": "org_1", "type": "agent.archived", "workspace_id": "ws_1"}
                    """,
                    { data in
                        guard case .agentArchived = data else { return XCTFail("expected .agentArchived") }
                    }
                ),
                (
                    """
                    {"id": "dep_1", "organization_id": "org_1", "type": "deployment.unpaused", "workspace_id": "ws_1"}
                    """,
                    { data in
                        guard case .deploymentUnpaused = data else { return XCTFail("expected .deploymentUnpaused") }
                    }
                ),
                (
                    """
                    {"id": "dr_1", "organization_id": "org_1", "type": "deployment_run.succeeded", "workspace_id": "ws_1"}
                    """,
                    { data in
                        guard case .deploymentRunSucceeded = data else {
                            return XCTFail("expected .deploymentRunSucceeded")
                        }
                    }
                ),
                (
                    """
                    {"id": "env_1", "organization_id": "org_1", "type": "environment.deleted", "workspace_id": "ws_1"}
                    """,
                    { data in
                        guard case .environmentDeleted = data else { return XCTFail("expected .environmentDeleted") }
                    }
                ),
                (
                    """
                    {"id": "ms_1", "organization_id": "org_1", "type": "memory_store.created", "workspace_id": "ws_1"}
                    """,
                    { data in
                        guard case .memoryStoreCreated = data else { return XCTFail("expected .memoryStoreCreated") }
                    }
                ),
                (
                    """
                    {"id": "vault_1", "organization_id": "org_1", "type": "vault.deleted", "workspace_id": "ws_1"}
                    """,
                    { data in
                        guard case .vaultDeleted = data else { return XCTFail("expected .vaultDeleted") }
                    }
                ),
            ]
        for testCase in cases {
            let data = try HTTPTransport.decoder.decode(
                BetaWebhookEventData.self, from: testCase.json.data(using: .utf8)!
            )
            testCase.verify(data)
        }
    }

    func testUnknownTypeFallsBackWithRawPayloadPreserved() throws {
        let fixture = """
        {"id": "x_1", "organization_id": "org_1", "type": "future.event", "workspace_id": "ws_1", "extra": 42}
        """.data(using: .utf8)!
        let data = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: fixture)
        guard case .unknown(let type, let raw) = data else {
            return XCTFail("expected .unknown, got \(data)")
        }
        XCTAssertEqual(type, "future.event")
        if case .object(let fields) = raw {
            XCTAssertEqual(fields["extra"], .number(42))
        } else {
            XCTFail("expected raw to decode as an object")
        }
    }

    func testUnwrapWebhookEventDecodesNestedData() throws {
        let fixture = """
        {"id": "whe_01ABC", "created_at": "2026-03-15T10:00:00Z",
         "data": {"id": "sesn_01ABC", "organization_id": "org_01ABC", "type": "session.status_idled",
                  "workspace_id": "wrkspc_01ABC"},
         "type": "event"}
        """.data(using: .utf8)!
        let event = try HTTPTransport.decoder.decode(UnwrapWebhookEvent.self, from: fixture)
        XCTAssertEqual(event.id, "whe_01ABC")
        XCTAssertEqual(event.type, "event")
        guard case .sessionStatusIdled(let session) = event.data else {
            return XCTFail("expected .sessionStatusIdled")
        }
        XCTAssertEqual(session.id, "sesn_01ABC")
    }

    // MARK: - user profile enforcement events

    func testDecodesBothUserProfileEnforcementEventsWithNoWorkspaceId() throws {
        // Unlike every other event data, these carry no `workspace_id`.
        let opened = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: Data("""
        {"id": "uprof_01ABC", "enforcement_action_id": "enac_01", "organization_id": "org_01",
         "type": "user_profile.enforcement_action_opened"}
        """.utf8))
        guard case .userProfileEnforcementActionOpened(let openedEvent) = opened else {
            return XCTFail("expected opened, got \(opened)")
        }
        XCTAssertEqual(openedEvent.id, "uprof_01ABC")
        XCTAssertEqual(openedEvent.enforcementActionId, "enac_01")
        XCTAssertEqual(openedEvent.organizationId, "org_01")

        let resolved = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: Data("""
        {"id": "uprof_01ABC", "enforcement_action_id": "enac_01", "organization_id": "org_01",
         "type": "user_profile.enforcement_action_resolved"}
        """.utf8))
        guard case .userProfileEnforcementActionResolved = resolved else {
            return XCTFail("expected resolved, got \(resolved)")
        }
    }

    func testAnUnrecognizedEventTypeStillDegradesToUnknown() throws {
        let data = try HTTPTransport.decoder.decode(BetaWebhookEventData.self, from: Data(#"{"id": "x", "type": "user_profile.something_new"}"#.utf8))
        guard case .unknown(let type, _) = data else { return XCTFail("expected .unknown") }
        XCTAssertEqual(type, "user_profile.something_new")
    }

    // MARK: - BetaWebhookEvent / parseUnverified

    private let envelope = """
    {"id": "evt_1", "created_at": "2026-10-10T00:00:00Z", "type": "event",
     "data": {"id": "uprof_1", "enforcement_action_id": "enac_1", "organization_id": "org_1",
              "type": "user_profile.enforcement_action_opened"}}
    """

    func testParseUnverifiedDecodesAnEnvelopeWithoutAnyHeadersOrKey() throws {
        let event = try AnthropicWebhooks.parseUnverified(payload: envelope)
        XCTAssertEqual(event.id, "evt_1")
        guard case .userProfileEnforcementActionOpened = event.data else { return XCTFail("expected opened, got \(event.data)") }
    }

    func testParseUnverifiedIsAlsoReachableThroughClientBetaWebhooks() throws {
        XCTAssertEqual(try BetaWebhooks().parseUnverified(payload: envelope).id, "evt_1")
    }

    func testParseUnverifiedRejectsPayloadsThatAreNotAnEnvelope() {
        XCTAssertThrowsError(try AnthropicWebhooks.parseUnverified(payload: "not json"))
        XCTAssertThrowsError(try AnthropicWebhooks.parseUnverified(payload: #"{"id": "evt_1"}"#))
    }

    func testUnwrapStillRefusesAnUnsignedPayloadSoParseUnverifiedIsTheOnlyWayAround() {
        XCTAssertThrowsError(try AnthropicWebhooks.unwrap(payload: envelope, headers: [:], key: "whsec_dGVzdA==")) { error in
            guard case AnthropicError.webhookValidation(let message) = error else { return XCTFail("expected webhookValidation, got \(error)") }
            XCTAssertEqual(message, "Missing required headers")
        }
    }

    func testUnwrapWebhookEventIsTheSameTypeAsBetaWebhookEvent() throws {
        let event: UnwrapWebhookEvent = try AnthropicWebhooks.parseUnverified(payload: envelope)
        let same: BetaWebhookEvent = event
        XCTAssertEqual(same.id, "evt_1")
    }
}
