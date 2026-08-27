import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaAgentVersionsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let agentFixture = """
    {
        "id": "agent_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "description": null,
        "mcp_servers": [],
        "metadata": {},
        "model": {"id": "claude-sonnet-5"},
        "multiagent": null,
        "name": "My Agent",
        "skills": [],
        "system": null,
        "tools": [],
        "type": "agent",
        "updated_at": "2026-01-15T00:00:00Z",
        "version": 2
    }
    """

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testListDecodesPageCursorOfAgentVersions() async throws {
        let fixture = """
        {"data": [\(Self.agentFixture)], "next_page": "page_2"}
        """.data(using: .utf8)!

        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/agents/agent_01ABC/versions")
            return self.jsonResponse(fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.agents.versions.list(agentId: "agent_01ABC", limit: 10)

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].version, 2)
        XCTAssertEqual(page.nextPage, "page_2")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "10")))
    }
}
