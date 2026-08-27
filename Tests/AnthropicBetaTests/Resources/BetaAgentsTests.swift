import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaAgentsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let agentFixture = """
    {
        "id": "agent_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "description": "test agent",
        "mcp_servers": [{"name": "docs", "type": "url", "url": "https://mcp.example.com"}],
        "metadata": {"team": "platform"},
        "model": {"id": "claude-sonnet-5", "effort": {"type": "high"}, "inference_geo": "us", "speed": "fast"},
        "multiagent": {
            "agents": [
                {"id": "agent_02DEF", "type": "agent", "version": 1},
                {"model": "claude-haiku-4-5", "type": "advisor"}
            ],
            "type": "coordinator"
        },
        "name": "My Agent",
        "skills": [
            {"skill_id": "skill_01", "type": "anthropic", "version": "1.0"},
            {"skill_id": "skill_02", "type": "custom", "version": "2.0"}
        ],
        "system": "You are helpful.",
        "tools": [
            {
                "type": "agent_toolset_20260401",
                "configs": [
                    {"enabled": true, "name": "bash", "permission_policy": {"type": "always_allow"}, "type": "bash"}
                ],
                "default_config": {"enabled": true, "permission_policy": {"type": "always_ask"}}
            }
        ],
        "type": "agent",
        "updated_at": "2026-01-15T00:00:00Z",
        "version": 1
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBareModelStringAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/agents")
            return self.jsonResponse(Self.agentFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let agent = try await client.beta.agents.create(
            BetaAgentCreateParams(model: "claude-sonnet-5", name: "My Agent")
        )

        XCTAssertEqual(agent.id, "agent_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-5")
        XCTAssertEqual(json["name"] as? String, "My Agent")
    }

    func testCreateWithModelConfigAndFullToolRosterEncodesAllVariants() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.agentFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.agents.create(
            BetaAgentCreateParams(
                model: .config(BetaManagedAgentsModelConfigParams(id: "claude-opus-5", effort: .high, speed: .fast)),
                name: "My Agent",
                mcpServers: [BetaManagedAgentsURLMCPServerParams(name: "docs", url: "https://mcp.example.com")],
                multiagent: BetaManagedAgentsMultiagentParams(
                    agents: [
                        "agent_bare_id",
                        .agent(BetaManagedAgentsAgentParams(id: "agent_02DEF", version: 3)),
                        .selfAgent(BetaManagedAgentsMultiagentSelfParams()),
                        .advisor(BetaManagedAgentsAdvisorParams(model: "claude-haiku-4-5")),
                    ]
                ),
                skills: [
                    .anthropic(BetaManagedAgentsAnthropicSkillParams(skillId: "skill_01")),
                    .custom(BetaManagedAgentsCustomSkillParams(skillId: "skill_02", version: "2.0")),
                ],
                tools: [
                    .agentToolset20260401(
                        BetaManagedAgentsAgentToolset20260401Params(
                            configs: [
                                .bash(BetaManagedAgentsBashToolConfigParams(enabled: true)),
                                .webSearch(BetaManagedAgentsWebSearchToolConfigParams(allowedDomains: ["example.com"])),
                            ]
                        )
                    ),
                    .mcpToolset(BetaManagedAgentsMCPToolsetParams(mcpServerName: "docs")),
                    .custom(
                        BetaManagedAgentsCustomToolParams(
                            description: "does a thing",
                            inputSchema: BetaManagedAgentsCustomToolInputSchemaParams(),
                            name: "my_tool"
                        )
                    ),
                ]
            )
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        let model = try XCTUnwrap(json["model"] as? [String: Any])
        XCTAssertEqual(model["id"] as? String, "claude-opus-5")
        XCTAssertEqual(model["effort"] as? String, "high")
        XCTAssertEqual(model["speed"] as? String, "fast")

        let roster = try XCTUnwrap(json["multiagent"] as? [String: Any])
        let agents = try XCTUnwrap(roster["agents"] as? [Any])
        XCTAssertEqual(agents.count, 4)
        XCTAssertEqual(agents[0] as? String, "agent_bare_id")
        let agentEntry = try XCTUnwrap(agents[1] as? [String: Any])
        XCTAssertEqual(agentEntry["type"] as? String, "agent")
        XCTAssertEqual(agentEntry["id"] as? String, "agent_02DEF")
        XCTAssertEqual(agentEntry["version"] as? Int, 3)
        let selfEntry = try XCTUnwrap(agents[2] as? [String: Any])
        XCTAssertEqual(selfEntry["type"] as? String, "self")
        let advisorEntry = try XCTUnwrap(agents[3] as? [String: Any])
        XCTAssertEqual(advisorEntry["type"] as? String, "advisor")
        XCTAssertEqual(advisorEntry["model"] as? String, "claude-haiku-4-5")

        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 3)
        let toolset = try XCTUnwrap(tools[0]["configs"] as? [[String: Any]])
        XCTAssertEqual(toolset[0]["name"] as? String, "bash")
        XCTAssertEqual(toolset[1]["name"] as? String, "web_search")
        XCTAssertEqual(toolset[1]["allowed_domains"] as? [String], ["example.com"])
        XCTAssertEqual(tools[1]["type"] as? String, "mcp_toolset")
        XCTAssertEqual(tools[2]["type"] as? String, "custom")
    }

    func testRetrieveDecodesFullAgentFixture() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/agents/agent_01ABC")
            return self.jsonResponse(Self.agentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let agent = try await client.beta.agents.retrieve("agent_01ABC")

        XCTAssertEqual(agent.model.id, "claude-sonnet-5")
        XCTAssertEqual(agent.model.effort, .high)
        XCTAssertEqual(agent.model.speed, .fast)

        let multiagent = try XCTUnwrap(agent.multiagent)
        XCTAssertEqual(multiagent.agents.count, 2)
        guard case .agent(let reference) = multiagent.agents[0] else {
            return XCTFail("Expected an agent reference")
        }
        XCTAssertEqual(reference.id, "agent_02DEF")
        XCTAssertEqual(reference.version, 1)
        guard case .advisor(let advisor) = multiagent.agents[1] else {
            return XCTFail("Expected an advisor")
        }
        XCTAssertEqual(advisor.model, "claude-haiku-4-5")

        XCTAssertEqual(agent.skills.count, 2)
        guard case .anthropic(let anthropicSkill) = agent.skills[0] else {
            return XCTFail("Expected an anthropic skill")
        }
        XCTAssertEqual(anthropicSkill.skillId, "skill_01")
        guard case .custom(let customSkill) = agent.skills[1] else {
            return XCTFail("Expected a custom skill")
        }
        XCTAssertEqual(customSkill.version, "2.0")

        XCTAssertEqual(agent.tools.count, 1)
        guard case .agentToolset20260401(let toolset) = agent.tools[0] else {
            return XCTFail("Expected the built-in agent toolset")
        }
        XCTAssertEqual(toolset.defaultConfig.permissionPolicy, .alwaysAsk)
        guard case .bash(let bash) = toolset.configs[0] else {
            return XCTFail("Expected a bash tool config")
        }
        XCTAssertEqual(bash.permissionPolicy, .alwaysAllow)
        XCTAssertTrue(bash.enabled)

        XCTAssertEqual(agent.mcpServers.first?.url, "https://mcp.example.com")
    }

    func testRetrieveSendsVersionQueryParam() async throws {
        MockURLProtocol.responder = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "version", value: "3")))
            return self.jsonResponse(Self.agentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.agents.retrieve("agent_01ABC", version: 3)
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.agentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.agents.update("agent_01ABC", BetaAgentUpdateParams(name: "Renamed"))

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["description"])
        XCTAssertNil(json["system"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["model"])
        XCTAssertNil(json["tools"])
        XCTAssertNil(json["skills"])
        XCTAssertNil(json["mcp_servers"])
        XCTAssertNil(json["multiagent"])
        XCTAssertNil(json["version"])
    }

    func testUpdateEmptyStringSetsDescriptionAndSystemAndPatchesMetadata() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.agentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.agents.update(
            "agent_01ABC",
            BetaAgentUpdateParams(
                description: "",
                system: "",
                mcpServers: [],
                metadata: ["old_key": nil, "new_key": "value"]
            )
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["description"] as? String, "")
        XCTAssertEqual(json["system"] as? String, "")
        XCTAssertEqual((json["mcp_servers"] as? [Any])?.count, 0)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertTrue(metadata["old_key"] is NSNull)
        XCTAssertEqual(metadata["new_key"] as? String, "value")
    }

    func testListSendsCreatedAtRangeAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.agentFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/agents")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[gte]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "false")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.agents.list(
            createdAtGte: "2026-01-01T00:00:00Z",
            includeArchived: false,
            limit: 5
        )
        XCTAssertEqual(page.data.count, 1)
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/agents/agent_01ABC/archive")
            return self.jsonResponse(Self.agentFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let agent = try await client.beta.agents.archive("agent_01ABC")
        XCTAssertEqual(agent.id, "agent_01ABC")
    }
}
