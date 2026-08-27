import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaDeploymentRunsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let runFixture = """
    {
        "id": "run_01ABC",
        "agent": {"id": "agent_01ABC", "type": "agent", "version": 1},
        "created_at": "2026-01-15T00:00:00Z",
        "deployment_id": "deploy_01ABC",
        "error": null,
        "session_id": "session_01ABC",
        "trigger_context": {"scheduled_at": "2026-01-15T00:00:00Z", "type": "schedule"},
        "type": "deployment_run"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testRetrieveDecodesDeploymentRun() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/deployment_runs/run_01ABC")
            return self.jsonResponse(Self.runFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let run = try await client.beta.deploymentRuns.retrieve("run_01ABC")
        XCTAssertEqual(run.sessionId, "session_01ABC")
    }

    func testListSendsBracketNotationAndFilterQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.runFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/deployment_runs")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[gt]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[gte]", value: "2026-01-02T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[lt]", value: "2026-02-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[lte]", value: "2026-02-02T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "deployment_id", value: "deploy_01ABC")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "has_error", value: "false")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "trigger_type", value: "schedule")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "10")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.deploymentRuns.list(
            createdAtGt: "2026-01-01T00:00:00Z",
            createdAtGte: "2026-01-02T00:00:00Z",
            createdAtLt: "2026-02-01T00:00:00Z",
            createdAtLte: "2026-02-02T00:00:00Z",
            deploymentId: "deploy_01ABC",
            hasError: false,
            limit: 10,
            triggerType: "schedule"
        )
        XCTAssertEqual(page.data.count, 1)
        guard case .schedule = page.data[0].triggerContext else {
            return XCTFail("Expected a schedule trigger context")
        }
    }
}
