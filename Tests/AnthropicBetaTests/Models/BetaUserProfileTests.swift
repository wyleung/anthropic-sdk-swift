import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaUserProfileTests: XCTestCase {
    func testDecodesNewerRelationshipBearingProfileWithMixedTrustGrants() throws {
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
            "access_type": null,
            "external_id": "ext_42",
            "name": "Ada Lovelace",
            "relationship": "external"
        }
        """.data(using: .utf8)!
        let profile = try HTTPTransport.decoder.decode(BetaUserProfile.self, from: fixture)
        XCTAssertEqual(profile.id, "uprof_01ABC")
        XCTAssertNil(profile.accessType)
        XCTAssertEqual(profile.relationship, .external)
        XCTAssertEqual(profile.trustGrants["device_binding"]?.status, .active)
        XCTAssertEqual(profile.trustGrants["payment_verification"]?.status, .pending)
        XCTAssertNil(profile.trustGrants["nonexistent_grant"])
    }

    func testDecodesOlderAccessTypeOnlyProfileWithNoTrustGrants() throws {
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
            "name": null,
            "relationship": null
        }
        """.data(using: .utf8)!
        let profile = try HTTPTransport.decoder.decode(BetaUserProfile.self, from: fixture)
        XCTAssertEqual(profile.accessType, .passthrough)
        XCTAssertNil(profile.relationship)
        XCTAssertTrue(profile.trustGrants.isEmpty)
    }

    func testTrustGrantStatusUnknownFallback() throws {
        let decoded = try HTTPTransport.decoder.decode(
            BetaUserProfileTrustGrantStatus.self, from: "\"revoked\"".data(using: .utf8)!
        )
        XCTAssertEqual(decoded, .unknown("revoked"))
    }

    func testAccessTypeAndRelationshipUnknownFallback() throws {
        let accessType = try HTTPTransport.decoder.decode(
            BetaUserProfileAccessType.self, from: "\"delegated\"".data(using: .utf8)!
        )
        XCTAssertEqual(accessType, .unknown("delegated"))

        let relationship = try HTTPTransport.decoder.decode(
            BetaUserProfileRelationship.self, from: "\"partner\"".data(using: .utf8)!
        )
        XCTAssertEqual(relationship, .unknown("partner"))
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
            accessType: .application, externalId: "ext_1", metadata: ["k": "v"], name: "Grace Hopper",
            relationship: .`internal`
        )
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["access_type"] as? String, "application")
        XCTAssertEqual(json["external_id"] as? String, "ext_1")
        XCTAssertEqual(json["name"] as? String, "Grace Hopper")
        XCTAssertEqual(json["relationship"] as? String, "internal")
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
