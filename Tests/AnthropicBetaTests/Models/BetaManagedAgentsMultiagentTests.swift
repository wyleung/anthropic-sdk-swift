import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// `multiagent_20261001` (advisor / subagents / workflows), inline agents, and Managed Agents web-fetch
/// `url_sources`.
final class BetaManagedAgentsMultiagentTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try HTTPTransport.decoder.decode(type, from: Data(json.utf8))
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: HTTPTransport.encoder.encode(value))
    }

    // MARK: - response: agent multiagent

    func testTheOriginalCoordinatorShapeStillDecodesAsACoordinator() throws {
        let multiagent = try decode(BetaManagedAgentsMultiagent.self, """
        {"type": "coordinator", "agents": [{"type": "agent", "id": "agent_1", "version": 3}, {"type": "advisor", "model": "claude-opus-5-5"}]}
        """)
        guard case .coordinator(let coordinator) = multiagent else { return XCTFail("expected coordinator") }
        XCTAssertEqual(coordinator.agents.count, 2)
    }

    func testMultiagent20261001DecodesEveryMemberAndItsEnabledPayload() throws {
        let multiagent = try decode(BetaManagedAgentsMultiagent.self, """
        {"type": "multiagent_20261001",
         "advisor": {"type": "enabled", "model": "claude-opus-5-5"},
         "subagents": {"type": "enabled", "inline_agents": {"type": "disabled"},
                       "predefined_agents": [{"type": "agent", "id": "agent_1", "version": 2}]},
         "workflows": {"type": "disabled"}}
        """)
        guard case .multiagent20261001(let config) = multiagent else { return XCTFail("expected multiagent_20261001") }
        guard case .enabled(let advisor) = config.advisor else { return XCTFail("advisor") }
        XCTAssertEqual(advisor.model, "claude-opus-5-5")
        guard case .enabled(let subagents) = config.subagents else { return XCTFail("subagents") }
        XCTAssertEqual(subagents.inlineAgents, .disabled)
        XCTAssertEqual(subagents.predefinedAgents.map(\.id), ["agent_1"])
        XCTAssertEqual(config.workflows, .disabled)
    }

    func testAnUnrecognizedMultiagentTypeOrToggleDegradesInsteadOfFailing() throws {
        guard case .unknown(let type, _) = try decode(BetaManagedAgentsMultiagent.self, #"{"type": "multiagent_20270101", "x": 1}"#) else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(type, "multiagent_20270101")
        let config = try decode(BetaManagedAgentsMultiagent20261001.self, """
        {"type": "multiagent_20261001", "advisor": {"type": "paused"}, "subagents": {"type": "disabled"}, "workflows": {"type": "disabled"}}
        """)
        guard case .unknown(let toggle, _) = config.advisor else { return XCTFail("expected an unknown advisor") }
        XCTAssertEqual(toggle, "paused")
    }

    func testMultiagentRoundTripsThroughEncodeSoItCanBeEchoedBack() throws {
        let wire = """
        {"type": "multiagent_20261001", "advisor": {"type": "disabled"}, "subagents": {"type": "disabled"},
         "workflows": {"type": "enabled", "inline_agents": {"type": "enabled"}, "predefined_agents": []}}
        """
        let value = try decode(BetaManagedAgentsMultiagent.self, wire)
        let echoed = try encoded(value) as? NSDictionary
        XCTAssertEqual(echoed, try JSONSerialization.jsonObject(with: Data(wire.utf8)) as? NSDictionary)
    }

    // MARK: - response: session multiagent + inline agents

    private func threadAgentJSON(id: String) -> String {
        """
        {"id": "\(id)", "type": "agent", "name": "worker", "version": 1, "description": null, "system": null,
         "mcp_servers": [], "model": {"id": "claude-opus-5-5"}, "skills": [], "tools": []}
        """
    }

    func testSessionMultiagentResolvesPredefinedAgentsToFullThreadAgents() throws {
        let multiagent = try decode(BetaManagedAgentsSessionMultiagent.self, """
        {"type": "multiagent_20261001", "advisor": {"type": "disabled"},
         "subagents": {"type": "enabled", "inline_agents": {"type": "enabled"}, "predefined_agents": [\(threadAgentJSON(id: "agent_7"))]},
         "workflows": {"type": "disabled"}}
        """)
        guard case .multiagent20261001(let config) = multiagent, case .enabled(let subagents) = config.subagents else {
            return XCTFail("expected an enabled session subagents")
        }
        XCTAssertEqual(subagents.predefinedAgents.first?.name, "worker")
        XCTAssertEqual(subagents.predefinedAgents.first?.id, "agent_7")
    }

    func testTheSessionCoordinatorShapeStillDecodes() throws {
        let multiagent = try decode(BetaManagedAgentsSessionMultiagent.self, """
        {"type": "coordinator", "agents": [\(threadAgentJSON(id: "agent_1")), {"type": "advisor", "model": "m"}]}
        """)
        guard case .coordinator(let coordinator) = multiagent else { return XCTFail("expected coordinator") }
        XCTAssertEqual(coordinator.agents.count, 2)
    }

    func testAnInlineAgentIsANewMemberOfTheThreadAgentUnion() throws {
        let agent = try decode(BetaManagedAgentsCoordinatorAgent.self, """
        {"type": "inline", "name": "scratch", "description": null, "system": "be brief", "mcp_servers": [],
         "model": {"id": "claude-opus-5-5"}, "skills": [], "tools": [],
         "execution_identity": {"type": "service_account"}}
        """)
        guard case .inline(let inline) = agent else { return XCTFail("expected .inline, got \(agent)") }
        XCTAssertEqual(inline.name, "scratch")
        XCTAssertEqual(inline.system, "be brief")
        guard case .serviceAccount = inline.executionIdentity else { return XCTFail("execution identity") }
    }

    // MARK: - params: the omit / useDefault / value distinction

    func testTheLegacyCoordinatorInitializerStillBuildsTheSameWireShape() throws {
        let legacy = BetaManagedAgentsMultiagentParams(agents: [.id("agent_1"), .selfAgent(BetaManagedAgentsMultiagentSelfParams())])
        let sent = try XCTUnwrap(try encoded(legacy) as? [String: Any])
        XCTAssertEqual(sent["type"] as? String, "coordinator")
        XCTAssertEqual((sent["agents"] as? [Any])?.count, 2)
        XCTAssertEqual((sent["agents"] as? [Any])?.first as? String, "agent_1", "an id is sent as a bare string")
    }

    func testOmittedMembersAreAbsentSoAnUpdateKeepsTheirStoredValue() throws {
        let sent = try XCTUnwrap(try encoded(BetaManagedAgentsMultiagentParams.multiagent20261001(
            BetaManagedAgentsMultiagent20261001Params(advisor: .disabled)
        )) as? [String: Any])
        XCTAssertEqual(sent["type"] as? String, "multiagent_20261001")
        XCTAssertEqual(sent["advisor"] as? NSDictionary, ["type": "disabled"])
        XCTAssertNil(sent["subagents"], "omitted must be absent: upstream merges, so absent keeps the stored value")
        XCTAssertNil(sent["workflows"])
    }

    func testUseDefaultIsSentAsAnExplicitNullWhichUpstreamTreatsDifferentlyFromOmitting() throws {
        let sent = try XCTUnwrap(try encoded(BetaManagedAgentsMultiagentParams.multiagent20261001(
            BetaManagedAgentsMultiagent20261001Params(advisor: .useDefault, subagents: .useDefault, workflows: .useDefault)
        )) as? [String: Any])
        for key in ["advisor", "subagents", "workflows"] {
            XCTAssertTrue(sent.keys.contains(key), "\(key) must be present...")
            XCTAssertTrue(sent[key] is NSNull, "...as JSON null, not omitted")
        }
    }

    func testEnabledTogglesCarryTheirPayloads() throws {
        let params = BetaManagedAgentsMultiagent20261001Params(
            advisor: .enabled(model: "claude-opus-5-5"),
            subagents: .enabled(
                inlineAgents: .disabled,
                predefinedAgents: [.id("agent_1"), .agent(BetaManagedAgentsAgentParams(id: "agent_2", version: 4)), .selfAgent(BetaManagedAgentsMultiagentSelfParams())]
            ),
            workflows: .enabled(inlineAgents: .useDefault)
        )
        let sent = try XCTUnwrap(try encoded(params) as? [String: Any])
        XCTAssertEqual(sent["advisor"] as? NSDictionary, ["type": "enabled", "model": "claude-opus-5-5"])

        let subagents = try XCTUnwrap(sent["subagents"] as? [String: Any])
        XCTAssertEqual(subagents["type"] as? String, "enabled")
        XCTAssertEqual(subagents["inline_agents"] as? NSDictionary, ["type": "disabled"])
        let predefined = try XCTUnwrap(subagents["predefined_agents"] as? [Any])
        XCTAssertEqual(predefined[0] as? String, "agent_1")
        XCTAssertEqual(predefined[1] as? NSDictionary, ["type": "agent", "id": "agent_2", "version": 4])
        XCTAssertEqual(predefined[2] as? NSDictionary, ["type": "self"])

        let workflows = try XCTUnwrap(sent["workflows"] as? [String: Any])
        XCTAssertTrue(workflows["inline_agents"] is NSNull, "a nested useDefault is a null too")
        XCTAssertNil(workflows["predefined_agents"], "omitted predefined_agents stays absent (null and [] both mean none)")
    }

    func testCreateAndUpdateCarryTheMultiagentUnion() throws {
        let multiagent = BetaManagedAgentsMultiagentParams.multiagent20261001(BetaManagedAgentsMultiagent20261001Params(workflows: .disabled))
        let create = try XCTUnwrap(try encoded(BetaAgentCreateParams(model: .model("claude-opus-5-5"), name: "a", multiagent: multiagent)) as? [String: Any])
        XCTAssertEqual((create["multiagent"] as? [String: Any])?["type"] as? String, "multiagent_20261001")
        let update = try XCTUnwrap(try encoded(BetaAgentUpdateParams(multiagent: multiagent, version: 2)) as? [String: Any])
        XCTAssertEqual(((update["multiagent"] as? [String: Any])?["workflows"] as? NSDictionary), ["type": "disabled"])
    }

    // MARK: - Managed Agents web fetch url_sources

    func testWebFetchToolConfigDecodesEveryUrlSourceShape() throws {
        let config = try decode(BetaManagedAgentsWebFetchToolConfig.self, """
        {"type": "web_fetch", "name": "web_fetch", "enabled": true, "permission_policy": {"type": "auto"},
         "url_sources": {
            "client_tool_results": {"type": "only", "tools": [{"type": "tool_reference", "name": "lookup"}]},
            "server_tool_results": {"type": "except", "tools": [{"type": "tool_reference", "name": "web_search"}]},
            "user_input": {"type": "none"}}}
        """)
        XCTAssertEqual(config.permissionPolicy, .auto)
        let sources = try XCTUnwrap(config.urlSources)
        XCTAssertEqual(sources.clientToolResults, .only([BetaManagedAgentsWebFetchURLSourceToolReference(name: "lookup")]))
        XCTAssertEqual(sources.serverToolResults, .except([BetaManagedAgentsWebFetchURLSourceToolReference(name: "web_search")]))
        XCTAssertEqual(sources.userInput, .nothing)
    }

    func testWebFetchToolConfigWithoutUrlSourcesStillDecodes() throws {
        let config = try decode(BetaManagedAgentsWebFetchToolConfig.self, """
        {"type": "web_fetch", "name": "web_fetch", "enabled": true, "permission_policy": {"type": "always_allow"}}
        """)
        XCTAssertNil(config.urlSources)
    }

    func testAnUnrecognizedUrlSourceVariantDegrades() throws {
        let sources = try decode(BetaManagedAgentsWebFetchURLSources.self, #"{"client_tool_results": {"type": "sampled", "rate": 0.5}}"#)
        guard case .unknown(let type, _) = sources.clientToolResults else { return XCTFail("expected .unknown") }
        XCTAssertEqual(type, "sampled")
    }

    func testWebFetchToolConfigParamsSendUrlSourcesInTheObjectForm() throws {
        let params = BetaManagedAgentsWebFetchToolConfigParams(
            urlSources: WebFetchURLSourcesParam(clientToolResults: .all, userInput: .nothing)
        )
        let sent = try XCTUnwrap(try encoded(params) as? [String: Any])
        let sources = try XCTUnwrap(sent["url_sources"] as? [String: Any])
        XCTAssertEqual(sources["client_tool_results"] as? NSDictionary, ["type": "all"])
        XCTAssertEqual(sources["user_input"] as? NSDictionary, ["type": "none"])
        XCTAssertNil(try XCTUnwrap(try encoded(BetaManagedAgentsWebFetchToolConfigParams()) as? [String: Any])["url_sources"])
    }
}
