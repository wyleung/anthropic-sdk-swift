import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsCredentialTests: XCTestCase {
    private static let credentialFixture = """
    {
        "id": "cred_01ABC",
        "archived_at": null,
        "auth": {"mcp_server_url": "https://mcp.example.com", "type": "static_bearer"},
        "created_at": "2026-01-15T00:00:00Z",
        "metadata": {},
        "type": "vault_credential",
        "updated_at": "2026-01-15T00:00:00Z",
        "vault_id": "vault_01ABC",
        "display_name": "Prod MCP Bearer"
    }
    """.data(using: .utf8)!

    func testDecodesCredential() throws {
        let credential = try HTTPTransport.decoder.decode(BetaManagedAgentsCredential.self, from: Self.credentialFixture)
        XCTAssertEqual(credential.id, "cred_01ABC")
        XCTAssertEqual(credential.vaultId, "vault_01ABC")
        XCTAssertEqual(credential.displayName, "Prod MCP Bearer")
        guard case .staticBearer(let auth) = credential.auth else {
            return XCTFail("Expected a static_bearer auth")
        }
        XCTAssertEqual(auth.mcpServerUrl, "https://mcp.example.com")
    }

    func testDecodesDeletedCredential() throws {
        let fixture = """
        {"id": "cred_01ABC", "type": "vault_credential_deleted"}
        """.data(using: .utf8)!
        let deleted = try HTTPTransport.decoder.decode(BetaManagedAgentsDeletedCredential.self, from: fixture)
        XCTAssertEqual(deleted.id, "cred_01ABC")
        XCTAssertEqual(deleted.type, "vault_credential_deleted")
    }

    func testCredentialValidationDecodesWithMCPProbeAndRefresh() throws {
        let fixture = """
        {
            "credential_id": "cred_01ABC",
            "has_refresh_token": true,
            "mcp_probe": {
                "http_response": {"body": "ok", "body_truncated": false, "content_type": "text/plain", "status_code": 200},
                "method": "GET"
            },
            "refresh": {
                "http_response": null,
                "status": "succeeded"
            },
            "status": "valid",
            "type": "vault_credential_validation",
            "validated_at": "2026-01-15T00:00:00Z",
            "vault_id": "vault_01ABC"
        }
        """.data(using: .utf8)!

        let validation = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialValidation.self, from: fixture)
        XCTAssertEqual(validation.status, .valid)
        XCTAssertTrue(validation.hasRefreshToken)
        let probe = try XCTUnwrap(validation.mcpProbe)
        XCTAssertEqual(probe.method, "GET")
        XCTAssertEqual(probe.httpResponse?.statusCode, 200)
        let refresh = try XCTUnwrap(validation.refresh)
        XCTAssertEqual(refresh.status, .succeeded)
        XCTAssertNil(refresh.httpResponse)

        let encoded = try HTTPTransport.encoder.encode(validation)
        let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialValidation.self, from: encoded)
        XCTAssertEqual(validation, roundTripped)
    }

    func testCredentialValidationStatusHandlesTheLiteralUnknownValueAndFutureValues() throws {
        let inconclusive = try HTTPTransport.decoder.decode(
            BetaManagedAgentsCredentialValidationStatus.self, from: "\"unknown\"".data(using: .utf8)!
        )
        XCTAssertEqual(inconclusive, .inconclusive)
        let encoded = try HTTPTransport.encoder.encode(inconclusive)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"unknown\"")

        let future = try HTTPTransport.decoder.decode(
            BetaManagedAgentsCredentialValidationStatus.self, from: "\"pending\"".data(using: .utf8)!
        )
        guard case .unrecognized(let value) = future else {
            return XCTFail("Expected an unrecognized status")
        }
        XCTAssertEqual(value, "pending")
    }

    func testRefreshStatusDecodesAllFourVariants() throws {
        let cases: [(String, BetaManagedAgentsRefreshStatus)] = [
            ("succeeded", .succeeded),
            ("failed", .failed),
            ("connect_error", .connectError),
            ("no_refresh_token", .noRefreshToken),
        ]
        for (raw, expected) in cases {
            let decoded = try HTTPTransport.decoder.decode(
                BetaManagedAgentsRefreshStatus.self, from: "\"\(raw)\"".data(using: .utf8)!
            )
            XCTAssertEqual(decoded, expected)
        }
    }
}
