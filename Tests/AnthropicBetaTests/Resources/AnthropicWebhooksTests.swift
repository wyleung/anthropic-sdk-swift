import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Fixture values (secret, payload, signatures) below were generated against the real Python
/// `standardwebhooks` PyPI package (v1.1.0, `Webhook.sign`), not derived from this Swift
/// implementation -- so a bug that made both sides wrong the same way can't hide here.
final class AnthropicWebhooksTests: XCTestCase {
    let secret = "whsec_c2VjcmV0Cg=="
    let payload = """
        {"id":"whe_0f1e2d3c4b5a69788796a5b4c3d2e1f0","created_at":"2026-03-15T10:00:00Z",\
        "data":{"id":"sesn_011CZkZAtmR3yMPDzynEDxu7","organization_id":"org_011CZkZZAe0sMna4vkBdtrfx",\
        "type":"session.status_idled","workspace_id":"wrkspc_011CZkZaBF1tNoB5wlCeusgy"},"type":"event"}
        """
    let msgId = "msg_01ABC"
    let timestampEpoch = "1773568800"
    let validSignature = "v1,UySEI/9wEZd8v6grZ+PZMHEwyimqMTWKnJrrRrpIee4="
    let tamperedSignature = "v1,WS51HsZU2OtzfbjJgFwX2D2PGUy+Hd/ZrQB00iA4upo="

    private var headers: [String: String] {
        ["webhook-id": msgId, "webhook-timestamp": timestampEpoch, "webhook-signature": validSignature]
    }

    private func fixedClock() -> Date { Date(timeIntervalSince1970: 1_773_568_800) }

    func testValidSignatureAcceptedAndDecoded() throws {
        let event = try AnthropicWebhooks.unwrap(
            payload: payload, headers: headers, key: secret, clock: fixedClock
        )
        XCTAssertEqual(event.id, "whe_0f1e2d3c4b5a69788796a5b4c3d2e1f0")
        XCTAssertEqual(event.type, "event")
        guard case .sessionStatusIdled(let session) = event.data else {
            return XCTFail("expected .sessionStatusIdled, got \(event.data)")
        }
        XCTAssertEqual(session.id, "sesn_011CZkZAtmR3yMPDzynEDxu7")
    }

    func testBareBase64SecretWithoutPrefixAlsoValidates() throws {
        let event = try AnthropicWebhooks.unwrap(
            payload: payload, headers: headers, key: "c2VjcmV0Cg==", clock: fixedClock
        )
        XCTAssertEqual(event.id, "whe_0f1e2d3c4b5a69788796a5b4c3d2e1f0")
    }

    func testHeaderLookupIsCaseInsensitive() throws {
        let shoutedHeaders = [
            "Webhook-Id": msgId, "WEBHOOK-TIMESTAMP": timestampEpoch, "Webhook-Signature": validSignature,
        ]
        let event = try AnthropicWebhooks.unwrap(
            payload: payload, headers: shoutedHeaders, key: secret, clock: fixedClock
        )
        XCTAssertEqual(event.id, "whe_0f1e2d3c4b5a69788796a5b4c3d2e1f0")
    }

    func testFirstMatchingSignatureWinsAmongMultipleCandidates() throws {
        var rotated = headers
        rotated["webhook-signature"] = "v1,notarealsignature== \(validSignature)"
        let event = try AnthropicWebhooks.unwrap(
            payload: payload, headers: rotated, key: secret, clock: fixedClock
        )
        XCTAssertEqual(event.id, "whe_0f1e2d3c4b5a69788796a5b4c3d2e1f0")
    }

    func testTamperedSignatureRejected() {
        var tampered = headers
        tampered["webhook-signature"] = tamperedSignature
        XCTAssertThrowsError(
            try AnthropicWebhooks.unwrap(payload: payload, headers: tampered, key: secret, clock: fixedClock)
        ) { error in
            guard case .webhookValidation(let message) = error as? AnthropicError else {
                return XCTFail("expected .webhookValidation, got \(error)")
            }
            XCTAssertEqual(message, "No matching signature found")
        }
    }

    func testTamperedPayloadRejected() {
        XCTAssertThrowsError(
            try AnthropicWebhooks.unwrap(payload: payload + "x", headers: headers, key: secret, clock: fixedClock)
        ) { error in
            guard case .webhookValidation(let message) = error as? AnthropicError else {
                return XCTFail("expected .webhookValidation, got \(error)")
            }
            XCTAssertEqual(message, "No matching signature found")
        }
    }

    func testExpiredTimestampRejected() {
        let farFuture = { Date(timeIntervalSince1970: 1_773_568_800 + 3600) }
        XCTAssertThrowsError(
            try AnthropicWebhooks.unwrap(payload: payload, headers: headers, key: secret, clock: farFuture)
        ) { error in
            guard case .webhookValidation(let message) = error as? AnthropicError else {
                return XCTFail("expected .webhookValidation, got \(error)")
            }
            XCTAssertEqual(message, "Message timestamp too old")
        }
    }

    func testFutureTimestampRejected() {
        let farPast = { Date(timeIntervalSince1970: 1_773_568_800 - 3600) }
        XCTAssertThrowsError(
            try AnthropicWebhooks.unwrap(payload: payload, headers: headers, key: secret, clock: farPast)
        ) { error in
            guard case .webhookValidation(let message) = error as? AnthropicError else {
                return XCTFail("expected .webhookValidation, got \(error)")
            }
            XCTAssertEqual(message, "Message timestamp too new")
        }
    }

    func testMissingHeaderRejected() {
        var incomplete = headers
        incomplete.removeValue(forKey: "webhook-signature")
        XCTAssertThrowsError(
            try AnthropicWebhooks.unwrap(payload: payload, headers: incomplete, key: secret, clock: fixedClock)
        ) { error in
            guard case .webhookValidation(let message) = error as? AnthropicError else {
                return XCTFail("expected .webhookValidation, got \(error)")
            }
            XCTAssertEqual(message, "Missing required headers")
        }
    }

    func testMalformedTimestampRejected() {
        var malformed = headers
        malformed["webhook-timestamp"] = "not-a-number"
        XCTAssertThrowsError(
            try AnthropicWebhooks.unwrap(payload: payload, headers: malformed, key: secret, clock: fixedClock)
        ) { error in
            guard case .webhookValidation(let message) = error as? AnthropicError else {
                return XCTFail("expected .webhookValidation, got \(error)")
            }
            XCTAssertEqual(message, "Invalid Signature Headers")
        }
    }

    func testBetaWebhooksForwarderMatchesStaticImplementation() throws {
        let beta = BetaWebhooks()
        let event = try beta.unwrap(payload: payload, headers: headers, key: secret, clock: fixedClock)
        XCTAssertEqual(event.id, "whe_0f1e2d3c4b5a69788796a5b4c3d2e1f0")
    }
}
