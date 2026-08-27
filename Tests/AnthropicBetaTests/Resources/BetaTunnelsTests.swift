import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaTunnelsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

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

    private static let tokenFixture = """
    {"id": "tun_01ABC", "tunnel_token": "tuntok_live_abc123", "type": "tunnel_token"}
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBodyAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/tunnels")
            return self.jsonResponse(Self.tunnelFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let tunnel = try await client.beta.tunnels.create(BetaTunnelCreateParams(displayName: "Staging MCP Tunnel"))
        XCTAssertEqual(tunnel.id, "tun_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "mcp-tunnels-2026-06-22")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "Staging MCP Tunnel")
    }

    func testRetrieveDecodesTunnel() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC")
            return self.jsonResponse(Self.tunnelFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let tunnel = try await client.beta.tunnels.retrieve("tun_01ABC")
        XCTAssertEqual(tunnel.domain, "tun-01abc.tunnels.anthropic.com")
    }

    func testListSendsFiltersAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.tunnelFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/tunnels")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "true")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.tunnels.list(includeArchived: true, limit: 5)
        XCTAssertEqual(page.data.count, 1)
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/archive")
            return self.jsonResponse(Self.tunnelFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.tunnels.archive("tun_01ABC")
    }

    func testRevealTokenPostsToRevealTokenPathAndDecodesToken() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/reveal_token")
            return self.jsonResponse(Self.tokenFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let token = try await client.beta.tunnels.revealToken("tun_01ABC")
        XCTAssertEqual(token.tunnelToken, "tuntok_live_abc123")
    }

    func testRotateTokenPostsBodyToRotateTokenPath() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/tunnels/tun_01ABC/rotate_token")
            return self.jsonResponse(Self.tokenFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let token = try await client.beta.tunnels.rotateToken(
            "tun_01ABC", BetaTunnelRotateTokenParams(reason: "scheduled rotation")
        )
        XCTAssertEqual(token.tunnelToken, "tuntok_live_abc123")

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["reason"] as? String, "scheduled rotation")
    }
}
