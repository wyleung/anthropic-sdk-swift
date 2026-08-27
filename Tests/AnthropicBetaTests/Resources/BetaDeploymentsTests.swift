import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaDeploymentsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let deploymentFixture = """
    {
        "id": "deploy_01ABC",
        "agent": {"id": "agent_01ABC", "type": "agent", "version": 1},
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "description": null,
        "environment_id": "env_01ABC",
        "initial_events": [],
        "metadata": {},
        "name": "My Deployment",
        "paused_reason": null,
        "resources": [],
        "schedule": null,
        "status": "active",
        "type": "deployment",
        "updated_at": "2026-01-15T00:00:00Z",
        "vault_ids": []
    }
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
            XCTAssertEqual(request.url?.path, "/v1/deployments")
            return self.jsonResponse(Self.deploymentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deployment = try await client.beta.deployments.create(
            BetaDeploymentCreateParams(
                agent: "agent_01ABC",
                environmentId: "env_01ABC",
                initialEvents: [],
                name: "My Deployment"
            )
        )
        XCTAssertEqual(deployment.id, "deploy_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["agent"] as? String, "agent_01ABC")
        XCTAssertEqual(json["environment_id"] as? String, "env_01ABC")
    }

    func testRetrieveDecodesDeployment() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/deployments/deploy_01ABC")
            return self.jsonResponse(Self.deploymentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deployment = try await client.beta.deployments.retrieve("deploy_01ABC")
        XCTAssertEqual(deployment.status, .active)
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.deploymentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.deployments.update("deploy_01ABC", BetaDeploymentUpdateParams(name: "Renamed"))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.path, "/v1/deployments/deploy_01ABC")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["resources"])
        XCTAssertNil(json["vault_ids"])
    }

    func testListSendsFiltersAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.deploymentFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/deployments")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "agent_id", value: "agent_01ABC")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[gte]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[lte]", value: "2026-02-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "status", value: "active")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.deployments.list(
            agentId: "agent_01ABC",
            createdAtGte: "2026-01-01T00:00:00Z",
            createdAtLte: "2026-02-01T00:00:00Z",
            limit: 5,
            status: "active"
        )
        XCTAssertEqual(page.data.count, 1)
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/deployments/deploy_01ABC/archive")
            return self.jsonResponse(Self.deploymentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.deployments.archive("deploy_01ABC")
    }

    func testPausePostsToPausePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/deployments/deploy_01ABC/pause")
            return self.jsonResponse(Self.deploymentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.deployments.pause("deploy_01ABC")
    }

    func testUnpausePostsToUnpausePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/deployments/deploy_01ABC/unpause")
            return self.jsonResponse(Self.deploymentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.deployments.unpause("deploy_01ABC")
    }

    func testRunPostsToRunPathAndReturnsADeploymentRun() async throws {
        let runFixture = """
        {
            "id": "run_01ABC",
            "agent": {"id": "agent_01ABC", "type": "agent", "version": 1},
            "created_at": "2026-01-15T00:00:00Z",
            "deployment_id": "deploy_01ABC",
            "error": null,
            "session_id": "session_01ABC",
            "trigger_context": {"type": "manual"},
            "type": "deployment_run"
        }
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/deployments/deploy_01ABC/run")
            return self.jsonResponse(runFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let run = try await client.beta.deployments.run("deploy_01ABC")
        XCTAssertEqual(run.id, "run_01ABC")
        XCTAssertEqual(run.deploymentId, "deploy_01ABC")
    }
}
