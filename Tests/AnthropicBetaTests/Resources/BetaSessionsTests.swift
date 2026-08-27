import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaSessionsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let sessionFixture = """
    {
        "id": "session_01ABC",
        "agent": {
            "id": "agent_01ABC",
            "description": null,
            "mcp_servers": [],
            "model": {"id": "claude-sonnet-5", "effort": null, "inference_geo": null, "speed": null},
            "multiagent": null,
            "name": "My Agent",
            "skills": [],
            "system": null,
            "tools": [],
            "type": "agent",
            "version": 1
        },
        "archived_at": null,
        "budget": {
            "max_list_cost": {"amount": "2500", "currency": "USD"},
            "type": "limit"
        },
        "created_at": "2026-01-15T00:00:00Z",
        "environment_id": "env_01ABC",
        "metadata": {"team": "platform"},
        "outcome_evaluations": [
            {
                "completed_at": null,
                "description": "Fix the bug",
                "explanation": null,
                "iteration": 1,
                "outcome_id": "outcome_01",
                "result": "running",
                "type": "outcome_evaluation"
            }
        ],
        "resources": [
            {
                "id": "resource_01ABC",
                "created_at": "2026-01-15T00:00:00Z",
                "file_id": "file_01ABC",
                "mount_path": "/data/report.pdf",
                "type": "file",
                "updated_at": "2026-01-15T00:00:00Z"
            }
        ],
        "stats": {"active_seconds": 12.5, "duration_seconds": 60.0},
        "status": "running",
        "title": "My Session",
        "type": "session",
        "updated_at": "2026-01-15T00:00:00Z",
        "usage": {
            "active_seconds": 12.5,
            "cache_creation": {"ephemeral_1h_input_tokens": 100, "ephemeral_5m_input_tokens": 50},
            "cache_read_input_tokens": 10,
            "input_tokens": 200,
            "list_cost": {"amount": "500", "currency": "USD"},
            "output_tokens": 300,
            "server_tool_use": {"web_fetch_requests": 1, "web_search_requests": 2}
        },
        "vault_ids": ["vault_01"],
        "deployment_id": null
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBareAgentStringAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/sessions")
            return self.jsonResponse(Self.sessionFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let session = try await client.beta.sessions.create(
            BetaSessionCreateParams(agent: "agent_01ABC", environmentId: "env_01ABC")
        )

        XCTAssertEqual(session.id, "session_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["agent"] as? String, "agent_01ABC")
        XCTAssertEqual(json["environment_id"] as? String, "env_01ABC")
    }

    func testCreateWithAgentWithOverridesAndResourcesEncodesAllVariants() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.sessionFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.sessions.create(
            BetaSessionCreateParams(
                agent: .agentWithOverrides(
                    BetaManagedAgentsAgentWithOverridesParams(
                        id: "agent_01ABC",
                        system: .some("Custom system prompt")
                    )
                ),
                environmentId: "env_01ABC",
                initialEvents: [
                    .userMessage(
                        BetaManagedAgentsUserMessageEventParams(
                            content: [.text(BetaManagedAgentsTextBlockParam(text: "Hello"))]
                        )
                    ),
                    .userDefineOutcome(
                        BetaManagedAgentsUserDefineOutcomeEventParams(
                            description: "Fix the bug",
                            rubric: .text(BetaManagedAgentsTextRubricParams(content: "must pass tests")),
                            maxIterations: 5
                        )
                    ),
                ],
                resources: [
                    .githubRepository(
                        BetaManagedAgentsGitHubRepositoryResourceParams(
                            authorizationToken: "tok",
                            url: "https://github.com/example/repo",
                            checkout: .branch(BetaManagedAgentsBranchCheckoutParam(name: "main"))
                        )
                    ),
                    .file(BetaManagedAgentsFileResourceParams(fileId: "file_01ABC", mountPath: "/data")),
                    .memoryStore(
                        BetaManagedAgentsMemoryStoreResourceParam(memoryStoreId: "mem_01", access: .readOnly)
                    ),
                ]
            )
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        let agent = try XCTUnwrap(json["agent"] as? [String: Any])
        XCTAssertEqual(agent["type"] as? String, "agent_with_overrides")
        XCTAssertEqual(agent["id"] as? String, "agent_01ABC")
        XCTAssertEqual(agent["system"] as? String, "Custom system prompt")

        let events = try XCTUnwrap(json["initial_events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0]["type"] as? String, "user.message")
        let content = try XCTUnwrap(events[0]["content"] as? [[String: Any]])
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[0]["text"] as? String, "Hello")
        XCTAssertEqual(events[1]["type"] as? String, "user.define_outcome")
        XCTAssertEqual(events[1]["max_iterations"] as? Int, 5)
        let rubric = try XCTUnwrap(events[1]["rubric"] as? [String: Any])
        XCTAssertEqual(rubric["type"] as? String, "text")
        XCTAssertEqual(rubric["content"] as? String, "must pass tests")

        let resources = try XCTUnwrap(json["resources"] as? [[String: Any]])
        XCTAssertEqual(resources.count, 3)
        XCTAssertEqual(resources[0]["type"] as? String, "github_repository")
        let checkout = try XCTUnwrap(resources[0]["checkout"] as? [String: Any])
        XCTAssertEqual(checkout["type"] as? String, "branch")
        XCTAssertEqual(checkout["name"] as? String, "main")
        XCTAssertEqual(resources[1]["type"] as? String, "file")
        XCTAssertEqual(resources[1]["file_id"] as? String, "file_01ABC")
        XCTAssertEqual(resources[2]["type"] as? String, "memory_store")
        XCTAssertEqual(resources[2]["access"] as? String, "read_only")
    }

    func testRetrieveDecodesSessionFixture() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC")
            return self.jsonResponse(Self.sessionFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let session = try await client.beta.sessions.retrieve("session_01ABC")

        XCTAssertEqual(session.status, .running)
        XCTAssertEqual(session.agent.model.id, "claude-sonnet-5")
        XCTAssertEqual(session.budget?.maxListCost.amount, "2500")
        XCTAssertEqual(session.usage.inputTokens, 200)
        XCTAssertEqual(session.usage.cacheCreation?.ephemeral1HInputTokens, 100)

        XCTAssertEqual(session.resources.count, 1)
        guard case .file(let file) = session.resources[0] else {
            return XCTFail("Expected a file resource")
        }
        XCTAssertEqual(file.fileId, "file_01ABC")
        XCTAssertEqual(file.mountPath, "/data/report.pdf")
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.sessionFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.sessions.update("session_01ABC", BetaSessionUpdateParams(title: "Renamed"))

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "Renamed")
        XCTAssertNil(json["agent"])
        XCTAssertNil(json["budget"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["vault_ids"])
    }

    func testUpdateAgentAndMetadataPatchSemantics() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.sessionFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.sessions.update(
            "session_01ABC",
            BetaSessionUpdateParams(
                agent: BetaManagedAgentsSessionAgentUpdateParam(
                    mcpServers: [BetaManagedAgentsURLMCPServerParams(name: "docs", url: "https://mcp.example.com")],
                    tools: []
                ),
                metadata: ["old_key": nil, "new_key": "value"],
                vaultIds: ["vault_02"]
            )
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        let agent = try XCTUnwrap(json["agent"] as? [String: Any])
        let mcpServers = try XCTUnwrap(agent["mcp_servers"] as? [[String: Any]])
        XCTAssertEqual(mcpServers[0]["name"] as? String, "docs")
        XCTAssertEqual((agent["tools"] as? [Any])?.count, 0)

        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertTrue(metadata["old_key"] is NSNull)
        XCTAssertEqual(metadata["new_key"] as? String, "value")
        XCTAssertEqual(json["vault_ids"] as? [String], ["vault_02"])
    }

    func testListSendsCreatedAtRangeStatusesAndDecodesBidirectionalCursor() async throws {
        let fixture = """
        {
            "data": [\(String(data: Self.sessionFixture, encoding: .utf8)!)],
            "next_page": "page_2",
            "prev_page": "page_0"
        }
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "created_at[gt]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "created_at[gte]", value: "2026-01-02T00:00:00Z")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "created_at[lt]", value: "2026-02-01T00:00:00Z")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "created_at[lte]", value: "2026-02-02T00:00:00Z")))
            let statuses = query.filter { $0.name == "statuses[]" }.map(\.value)
            XCTAssertEqual(statuses, ["running", "idle"])
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.sessions.list(
            createdAtGt: "2026-01-01T00:00:00Z",
            createdAtGte: "2026-01-02T00:00:00Z",
            createdAtLt: "2026-02-01T00:00:00Z",
            createdAtLte: "2026-02-02T00:00:00Z",
            statuses: ["running", "idle"]
        )
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.nextPage, "page_2")
        XCTAssertEqual(page.prevPage, "page_0")
    }

    func testDeleteDecodesDeletedSession() async throws {
        let fixture = """
        {"id": "session_01ABC", "type": "session_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.sessions.delete("session_01ABC")
        XCTAssertEqual(deleted.type, "session_deleted")
    }

    func testArchivePostsToArchivePath() async throws {
        let archived = String(data: Self.sessionFixture, encoding: .utf8)!
            .replacingOccurrences(of: "\"archived_at\": null", with: "\"archived_at\": \"2026-01-16T00:00:00Z\"")
            .data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/archive")
            return self.jsonResponse(archived)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let session = try await client.beta.sessions.archive("session_01ABC")
        XCTAssertEqual(session.archivedAt, "2026-01-16T00:00:00Z")
    }
}
