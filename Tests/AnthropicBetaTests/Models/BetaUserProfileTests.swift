import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaUserProfileTests: XCTestCase {
    func testDecodesProfileWithMixedTrustGrantsAndExternalOnboardingFields() throws {
        let fixture = """
        {
            "id": "uprof_01ABC",
            "created_at": "2026-01-15T00:00:00Z",
            "metadata": {"team": "growth"},
            "trust_grants": {
                "device_binding": {"status": "active"},
                "payment_verification": {"status": "pending"}
            },
            "type": "user_profile",
            "updated_at": "2026-01-16T00:00:00Z",
            "access_type": "application",
            "external_id": "ext_42",
            "external_user_onboarded_at": "2026-01-01T00:00:00Z",
            "name": "Ada Lovelace"
        }
        """.data(using: .utf8)!
        let profile = try HTTPTransport.decoder.decode(BetaUserProfile.self, from: fixture)
        XCTAssertEqual(profile.id, "uprof_01ABC")
        XCTAssertEqual(profile.accessType, .application)
        XCTAssertEqual(profile.externalUserOnboardedAt, "2026-01-01T00:00:00Z")
        XCTAssertNil(profile.externalUserDetails, "only present when no legacy beta header is sent")
        XCTAssertEqual(profile.trustGrants["device_binding"]?.status, .active)
        XCTAssertEqual(profile.trustGrants["payment_verification"]?.status, .pending)
        XCTAssertNil(profile.trustGrants["nonexistent_grant"])
    }

    func testDecodesPassthroughProfileWithNoTrustGrants() throws {
        let fixture = """
        {
            "id": "uprof_01DEF",
            "created_at": "2026-01-15T00:00:00Z",
            "metadata": {},
            "trust_grants": {},
            "type": "user_profile",
            "updated_at": "2026-01-15T00:00:00Z",
            "access_type": "passthrough",
            "external_id": null,
            "name": null
        }
        """.data(using: .utf8)!
        let profile = try HTTPTransport.decoder.decode(BetaUserProfile.self, from: fixture)
        XCTAssertEqual(profile.accessType, .passthrough)
        XCTAssertTrue(profile.trustGrants.isEmpty)
        XCTAssertNil(profile.externalUserOnboardedAt)
    }

    func testTrustGrantStatusUnknownFallback() throws {
        let decoded = try HTTPTransport.decoder.decode(
            BetaUserProfileTrustGrantStatus.self, from: "\"revoked\"".data(using: .utf8)!
        )
        XCTAssertEqual(decoded, .unknown("revoked"))
    }

    func testAccessTypeUnknownFallback() throws {
        let accessType = try HTTPTransport.decoder.decode(
            BetaUserProfileAccessType.self, from: "\"delegated\"".data(using: .utf8)!
        )
        XCTAssertEqual(accessType, .unknown("delegated"))
    }

    func testAProfileStillCarryingTheRetiredRelationshipFieldDecodesAndIgnoresIt() throws {
        // `relationship` was replaced by `access_type`; a payload that still includes it must not fail.
        let profile = try HTTPTransport.decoder.decode(BetaUserProfile.self, from: Data("""
        {"id": "u", "created_at": "t", "metadata": {}, "trust_grants": {}, "type": "user_profile",
         "updated_at": "t", "relationship": "external"}
        """.utf8))
        XCTAssertEqual(profile.id, "u")
    }

    func testEnrollmentURLDecodes() throws {
        let fixture = """
        {
            "expires_at": "2026-02-01T00:00:00Z",
            "type": "enrollment_url",
            "url": "https://claude.ai/enroll/abc123"
        }
        """.data(using: .utf8)!
        let enrollment = try HTTPTransport.decoder.decode(BetaUserProfileEnrollmentURL.self, from: fixture)
        XCTAssertEqual(enrollment.expiresAt, "2026-02-01T00:00:00Z")
        XCTAssertEqual(enrollment.url, "https://claude.ai/enroll/abc123")
    }

    func testCreateParamsOmitsAllFieldsWhenUnset() throws {
        let data = try HTTPTransport.encoder.encode(BetaUserProfileCreateParams())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(json.isEmpty)
    }

    func testCreateParamsEncodesProvidedFields() throws {
        let params = BetaUserProfileCreateParams(
            accessType: .application, externalId: "ext_1", externalUserOnboardedAt: "2026-01-01T00:00:00Z",
            metadata: ["k": "v"], name: "Grace Hopper"
        )
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["access_type"] as? String, "application")
        XCTAssertEqual(json["external_id"] as? String, "ext_1")
        XCTAssertEqual(json["name"] as? String, "Grace Hopper")
        XCTAssertEqual(json["external_user_onboarded_at"] as? String, "2026-01-01T00:00:00Z")
        XCTAssertNil(json["relationship"], "relationship is gone from the params")
    }

    func testUpdateParamsMetadataPatchEncodesNullForClearedKeyAndOmitsAbsentField() throws {
        let params = BetaUserProfileUpdateParams(metadata: ["keep": "value", "clear_me": nil])
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json.count, 1)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["keep"] as? String, "value")
        XCTAssertTrue(metadata["clear_me"] is NSNull)
    }
}
