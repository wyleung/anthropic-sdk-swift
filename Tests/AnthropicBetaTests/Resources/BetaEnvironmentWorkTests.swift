import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaEnvironmentWorkTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let workFixture = """
    {
        "id": "work_01ABC",
        "acknowledged_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "data": {"id": "session_01ABC", "type": "session"},
        "environment_id": "env_01ABC",
        "latest_heartbeat_at": null,
        "metadata": {"team": "platform"},
        "secret": null,
        "started_at": null,
        "state": "active",
        "stop_requested_at": null,
        "stopped_at": null,
        "type": "work"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testRetrieveDecodesWorkItem() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/work_01ABC")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")
            return self.jsonResponse(Self.workFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let work = try await client.beta.environments.work.retrieve(environmentId: "env_01ABC", workId: "work_01ABC")
        XCTAssertEqual(work.state, .active)
        XCTAssertEqual(work.data.id, "session_01ABC")
    }

    func testUpdateSendsMetadataPatch() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/work_01ABC")
            return self.jsonResponse(Self.workFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.environments.work.update(
            environmentId: "env_01ABC",
            workId: "work_01ABC",
            BetaWorkUpdateParams(metadata: ["old_key": nil, "new_key": "value"])
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertTrue(metadata["old_key"] is NSNull)
        XCTAssertEqual(metadata["new_key"] as? String, "value")
    }

    func testListDecodesPageCursor() async throws {
        let fixture = """
        {"data": [\(String(data: Self.workFixture, encoding: .utf8)!)], "next_page": "cursor_abc"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.environments.work.list(environmentId: "env_01ABC", limit: 5)
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.nextPage, "cursor_abc")
    }

    func testAckPostsToAckPath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/work_01ABC/ack")
            return self.jsonResponse(Self.workFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let work = try await client.beta.environments.work.ack(environmentId: "env_01ABC", workId: "work_01ABC")
        XCTAssertEqual(work.id, "work_01ABC")
    }

    func testHeartbeatSendsQueryParamsNotBody() async throws {
        let fixture = """
        {"last_heartbeat": "2026-01-15T00:05:00Z", "lease_extended": true, "state": "active", "ttl_seconds": 30, "type": "work_heartbeat"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/work_01ABC/heartbeat")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "desired_ttl_seconds", value: "30")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "expected_last_heartbeat", value: "NO_HEARTBEAT")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let response = try await client.beta.environments.work.heartbeat(
            environmentId: "env_01ABC",
            workId: "work_01ABC",
            desiredTtlSeconds: 30,
            expectedLastHeartbeat: "NO_HEARTBEAT"
        )
        XCTAssertEqual(response.leaseExtended, true)
        XCTAssertEqual(response.state, .active)
    }

    func testPollSendsWorkerIdHeaderAndDecodesWork() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/poll")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Anthropic-Worker-ID"), "worker-1")
            return self.jsonResponse(Self.workFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let work = try await client.beta.environments.work.poll(
            environmentId: "env_01ABC",
            blockMs: 500,
            workerId: "worker-1"
        )
        XCTAssertEqual(work?.id, "work_01ABC")
    }

    func testPollReturnsNilWhenNoWorkAvailable() async throws {
        MockURLProtocol.responder = { _ in self.jsonResponse(Data("null".utf8)) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let work = try await client.beta.environments.work.poll(environmentId: "env_01ABC")
        XCTAssertNil(work)
    }

    func testStatsDecodesQueueStats() async throws {
        let fixture = """
        {"depth": 3, "oldest_queued_at": "2026-01-15T00:00:00Z", "pending": 1, "type": "work_queue_stats", "workers_polling": 2}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/stats")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let stats = try await client.beta.environments.work.stats(environmentId: "env_01ABC")
        XCTAssertEqual(stats.depth, 3)
        XCTAssertEqual(stats.workersPolling, 2)
    }

    func testStopSendsForceInBody() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/work/work_01ABC/stop")
            return self.jsonResponse(Self.workFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.environments.work.stop(environmentId: "env_01ABC", workId: "work_01ABC", force: true)

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["force"] as? Bool, true)
    }
}
