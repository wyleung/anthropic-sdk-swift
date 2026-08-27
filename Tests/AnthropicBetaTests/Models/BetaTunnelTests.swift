import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaTunnelTests: XCTestCase {
    private static let tunnelFixture = """
    {
        "id": "tun_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "display_name": "Staging MCP Tunnel",
        "domain": "tun-01abc.tunnels.anthropic.com",
        "type": "tunnel"
    }
    """.data(using: .utf8)!

    func testDecodesTunnel() throws {
        let tunnel = try HTTPTransport.decoder.decode(BetaTunnel.self, from: Self.tunnelFixture)
        XCTAssertEqual(tunnel.id, "tun_01ABC")
        XCTAssertNil(tunnel.archivedAt)
        XCTAssertEqual(tunnel.displayName, "Staging MCP Tunnel")
        XCTAssertEqual(tunnel.domain, "tun-01abc.tunnels.anthropic.com")
        XCTAssertEqual(tunnel.type, "tunnel")
    }

    func testDecodesTunnelWithNoDisplayName() throws {
        let fixture = """
        {"id": "tun_01ABC", "created_at": "2026-01-15T00:00:00Z",
         "domain": "tun-01abc.tunnels.anthropic.com", "type": "tunnel"}
        """.data(using: .utf8)!
        let tunnel = try HTTPTransport.decoder.decode(BetaTunnel.self, from: fixture)
        XCTAssertNil(tunnel.displayName)
    }

    func testDecodesTunnelToken() throws {
        let fixture = """
        {"id": "tun_01ABC", "tunnel_token": "tuntok_live_abc123", "type": "tunnel_token"}
        """.data(using: .utf8)!
        let token = try HTTPTransport.decoder.decode(BetaTunnelToken.self, from: fixture)
        XCTAssertEqual(token.id, "tun_01ABC")
        XCTAssertEqual(token.tunnelToken, "tuntok_live_abc123")
        XCTAssertEqual(token.type, "tunnel_token")
    }

    func testDecodesTunnelCertificate() throws {
        let fixture = """
        {"id": "tcrt_01ABC", "archived_at": null, "created_at": "2026-01-15T00:00:00Z",
         "expires_at": "2027-01-15T00:00:00Z",
         "fingerprint": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
         "tunnel_id": "tun_01ABC", "type": "tunnel_certificate"}
        """.data(using: .utf8)!
        let certificate = try HTTPTransport.decoder.decode(BetaTunnelCertificate.self, from: fixture)
        XCTAssertEqual(certificate.id, "tcrt_01ABC")
        XCTAssertNil(certificate.archivedAt)
        XCTAssertEqual(certificate.expiresAt, "2027-01-15T00:00:00Z")
        XCTAssertEqual(
            certificate.fingerprint, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        )
        XCTAssertEqual(certificate.tunnelId, "tun_01ABC")
        XCTAssertEqual(certificate.type, "tunnel_certificate")
    }

    func testTunnelCreateParamsOmitsDisplayNameWhenNil() throws {
        let params = BetaTunnelCreateParams()
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["display_name"])
    }

    func testTunnelCreateParamsEncodesDisplayName() throws {
        let params = BetaTunnelCreateParams(displayName: "Staging MCP Tunnel")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "Staging MCP Tunnel")
    }

    func testTunnelRotateTokenParamsOmitsReasonWhenNil() throws {
        let params = BetaTunnelRotateTokenParams()
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["reason"])
    }

    func testCertificateCreateParamsEncodesCaCertificatePem() throws {
        let params = BetaCertificateCreateParams(caCertificatePem: "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(
            json["ca_certificate_pem"] as? String,
            "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"
        )
    }
}
