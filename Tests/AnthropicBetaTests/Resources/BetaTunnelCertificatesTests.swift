import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaTunnelCertificatesTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let certificateFixture = """
    {
        "id": "tcrt_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "expires_at": "2027-01-15T00:00:00Z",
        "fingerprint": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
        "tunnel_id": "tun_01ABC",
        "type": "tunnel_certificate"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBodyToNestedPath() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/certificates")
            return self.jsonResponse(Self.certificateFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let certificate = try await client.beta.tunnels.certificates.create(
            tunnelId: "tun_01ABC", BetaCertificateCreateParams(caCertificatePem: "-----BEGIN CERTIFICATE-----")
        )
        XCTAssertEqual(certificate.id, "tcrt_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "mcp-tunnels-2026-06-22")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["ca_certificate_pem"] as? String, "-----BEGIN CERTIFICATE-----")
    }

    func testRetrieveUsesTunnelIdThenCertificateIdInPath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/certificates/tcrt_01ABC")
            return self.jsonResponse(Self.certificateFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let certificate = try await client.beta.tunnels.certificates.retrieve(
            tunnelId: "tun_01ABC", certificateId: "tcrt_01ABC"
        )
        XCTAssertEqual(certificate.fingerprint.count, 64)
    }

    func testListSendsFiltersAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.certificateFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/certificates")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "true")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.tunnels.certificates.list(
            tunnelId: "tun_01ABC", includeArchived: true, limit: 5
        )
        XCTAssertEqual(page.data.count, 1)
    }

    func testArchivePostsToArchivePathWithTunnelIdThenCertificateId() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/certificates/tcrt_01ABC/archive")
            return self.jsonResponse(Self.certificateFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.tunnels.certificates.archive(tunnelId: "tun_01ABC", certificateId: "tcrt_01ABC")
    }
}
