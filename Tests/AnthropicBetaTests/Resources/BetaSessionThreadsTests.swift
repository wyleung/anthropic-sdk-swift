import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaSessionThreadsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let threadFixture = """
    {
        "id": "thread_01ABC",
        "agent": {
            "id": "agent_01ABC",
            "description": null,
            "mcp_servers": [],
            "model": {"id": "claude-sonnet-5", "effort": null, "inference_geo": null, "speed": null},
            "name": "My Agent",
            "skills": [],
            "system": null,
            "tools": [],
            "type": "agent",
            "version": 1
        },
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "parent_thread_id": null,
        "session_id": "session_01ABC",
        "stats": {"active_seconds": 5.0, "duration_seconds": 10.0, "startup_seconds": 1.5},
        "status": "running",
        "type": "session_thread",
        "updated_at": "2026-01-15T00:00:00Z",
        "usage": {
            "active_seconds": 5.0,
            "cache_creation": {"ephemeral_1h_input_tokens": 20, "ephemeral_5m_input_tokens": 10},
            "cache_read_input_tokens": 2,
            "input_tokens": 40,
            "list_cost": {"amount": "100", "currency": "USD"},
            "output_tokens": 60,
            "server_tool_use": {"web_fetch_requests": 0, "web_search_requests": 1}
        }
    }
    """.data(using: .utf8)!

    private static let advisorThreadFixture = """
    {
        "id": "thread_02ABC",
        "agent": {"model": "claude-sonnet-5", "type": "advisor"},
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "parent_thread_id": "thread_01ABC",
        "session_id": "session_01ABC",
        "stats": null,
        "status": "idle",
        "type": "session_thread",
        "updated_at": "2026-01-15T00:00:00Z",
        "usage": null
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testRetrieveDecodesThreadWithAgentVariant() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/threads/thread_01ABC")
            return self.jsonResponse(Self.threadFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let thread = try await client.beta.sessions.threads.retrieve("thread_01ABC", sessionId: "session_01ABC")

        XCTAssertEqual(thread.status, .running)
        XCTAssertEqual(thread.stats?.startupSeconds, 1.5)
        XCTAssertEqual(thread.usage?.cacheCreation?.ephemeral1HInputTokens, 20)

        guard case .agent(let agent) = thread.agent else {
            return XCTFail("Expected an agent coordinator variant")
        }
        XCTAssertEqual(agent.id, "agent_01ABC")
        XCTAssertEqual(agent.model.id, "claude-sonnet-5")
    }

    func testRetrieveDecodesThreadWithAdvisorVariant() async throws {
        MockURLProtocol.responder = { request in
            self.jsonResponse(Self.advisorThreadFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let thread = try await client.beta.sessions.threads.retrieve("thread_02ABC", sessionId: "session_01ABC")

        XCTAssertEqual(thread.status, .idle)
        XCTAssertEqual(thread.parentThreadId, "thread_01ABC")
        XCTAssertNil(thread.usage)

        guard case .advisor(let advisor) = thread.agent else {
            return XCTFail("Expected an advisor coordinator variant")
        }
        XCTAssertEqual(advisor.model, "claude-sonnet-5")
    }

    func testListSendsLimitAndPageAndDecodesForwardCursor() async throws {
        let fixture = """
        {
            "data": [\(String(data: Self.threadFixture, encoding: .utf8)!)],
            "next_page": "page_2"
        }
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/threads")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "5")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "page", value: "page_1")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.sessions.threads.list(
            sessionId: "session_01ABC", limit: 5, page: "page_1"
        )
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.nextPage, "page_2")
    }

    func testArchivePostsToArchivePath() async throws {
        let archived = String(data: Self.threadFixture, encoding: .utf8)!
            .replacingOccurrences(of: "\"archived_at\": null", with: "\"archived_at\": \"2026-01-16T00:00:00Z\"")
            .data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/threads/thread_01ABC/archive")
            return self.jsonResponse(archived)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let thread = try await client.beta.sessions.threads.archive("thread_01ABC", sessionId: "session_01ABC")
        XCTAssertEqual(thread.archivedAt, "2026-01-16T00:00:00Z")
    }
}
