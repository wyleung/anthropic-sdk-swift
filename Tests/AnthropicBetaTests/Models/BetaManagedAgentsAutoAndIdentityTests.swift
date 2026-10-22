import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Managed Agents additions: the `auto` permission policy and its per-call evaluations, agent
/// `execution_identity`, optional GitHub tokens, and the threads `statuses` filter.
final class BetaManagedAgentsAutoAndIdentityTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try HTTPTransport.decoder.decode(type, from: Data(json.utf8))
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: HTTPTransport.encoder.encode(value))
    }

    // MARK: - auto permission policy

    func testAutoPolicyDecodesAndEncodesOnTheSharedPolicyType() throws {
        XCTAssertEqual(try decode(BetaManagedAgentsPermissionPolicy.self, #"{"type": "auto"}"#), .auto)
        XCTAssertEqual(try encoded(BetaManagedAgentsPermissionPolicy.auto) as? NSDictionary, ["type": "auto"])
        // The existing two still work, and a future policy still degrades rather than failing.
        XCTAssertEqual(try decode(BetaManagedAgentsPermissionPolicy.self, #"{"type": "always_ask"}"#), .alwaysAsk)
        guard case .unknown(let type, _) = try decode(BetaManagedAgentsPermissionPolicy.self, #"{"type": "cautious"}"#) else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(type, "cautious")
    }

    func testAutoPolicyReachesTheWireThroughAToolConfig() throws {
        let sent = try XCTUnwrap(try encoded(BetaManagedAgentsBashToolConfigParams(permissionPolicy: .auto)) as? [String: Any])
        XCTAssertEqual(sent["permission_policy"] as? NSDictionary, ["type": "auto"])
    }

    // MARK: - tool-use events carry the evaluation

    private func toolUseEvent(extra: String) -> String {
        """
        {"id": "sevt_1", "type": "agent.tool_use", "name": "bash", "input": {"command": "ls"},
         "processed_at": "2026-10-01T00:00:00Z", "evaluated_permission": "deny"\(extra)}
        """
    }

    func testAutoEvaluationDecodesTheServersVerdictAndReason() throws {
        let event = try decode(BetaManagedAgentsAgentToolUseEvent.self, toolUseEvent(extra: """
        , "evaluation": {"type": "auto", "evaluated_permission": {"type": "deny", "reason_code": "destructive_command"}}
        """))
        XCTAssertEqual(event.evaluatedPermission, .deny)
        guard case .auto(let auto) = event.evaluation, case .deny(let deny) = auto.evaluatedPermission else {
            return XCTFail("expected auto/deny, got \(String(describing: event.evaluation))")
        }
        XCTAssertEqual(deny.reasonCode, "destructive_command")
    }

    func testEveryAutoVerdictShapeDecodes() throws {
        func verdict(_ json: String) throws -> BetaManagedAgentsAgentAutoEvaluatedPermission {
            try decode(BetaManagedAgentsAgentAutoEvaluatedPermission.self, json)
        }
        guard case .allow = try verdict(#"{"type": "allow"}"#) else { return XCTFail("allow") }
        guard case .ask(let ask) = try verdict(#"{"type": "ask", "reason_code": "unsure"}"#) else { return XCTFail("ask") }
        XCTAssertEqual(ask.reasonCode, "unsure")
        guard case .unknown(let type, _) = try verdict(#"{"type": "escalate"}"#) else { return XCTFail("unknown") }
        XCTAssertEqual(type, "escalate")
    }

    func testStaticPolicyEvaluationsDecodeAndAnUnknownOneDegrades() throws {
        func evaluation(_ json: String) throws -> BetaManagedAgentsAgentToolEvaluation {
            try decode(BetaManagedAgentsAgentToolEvaluation.self, json)
        }
        guard case .alwaysAllow = try evaluation(#"{"type": "always_allow"}"#) else { return XCTFail("always_allow") }
        guard case .alwaysAsk = try evaluation(#"{"type": "always_ask"}"#) else { return XCTFail("always_ask") }
        guard case .unknown = try evaluation(#"{"type": "learned"}"#) else { return XCTFail("unknown") }
    }

    func testToolUseEventsWithoutAnEvaluationStillDecode() throws {
        XCTAssertNil(try decode(BetaManagedAgentsAgentToolUseEvent.self, toolUseEvent(extra: "")).evaluation)
    }

    func testPublicInitializersKeepTheEvaluationSoHandBuiltEventsDontLoseIt() {
        // Decoding uses the synthesized `Decodable`, so this is the only thing that exercises the public inits.
        let evaluation = BetaManagedAgentsAgentToolEvaluation.alwaysAsk(BetaManagedAgentsAgentToolEvaluationAlwaysAsk())
        let tool = BetaManagedAgentsAgentToolUseEvent(
            id: "e", input: [:], name: "bash", processedAt: "t", evaluatedPermission: .ask, evaluation: evaluation
        )
        XCTAssertEqual(tool.evaluation, evaluation)
        let mcp = BetaManagedAgentsAgentMCPToolUseEvent(
            id: "e", input: [:], mcpServerName: "docs", name: "search", processedAt: "t", evaluation: evaluation
        )
        XCTAssertEqual(mcp.evaluation, evaluation)
    }

    func testMcpToolUseEventsCarryTheEvaluationToo() throws {
        let event = try decode(BetaManagedAgentsAgentMCPToolUseEvent.self, """
        {"id": "sevt_2", "type": "agent.mcp_tool_use", "name": "search", "mcp_server_name": "docs", "input": {},
         "processed_at": "2026-10-01T00:00:00Z", "evaluated_permission": "allow",
         "evaluation": {"type": "auto", "evaluated_permission": {"type": "allow"}}}
        """)
        guard case .auto(let auto) = event.evaluation, case .allow = auto.evaluatedPermission else {
            return XCTFail("expected auto/allow")
        }
    }

    // MARK: - execution identity

    private let agentWire = """
    {"id": "agent_1", "archived_at": null, "created_at": "2026-10-01T00:00:00Z", "description": null,
     "mcp_servers": [], "metadata": {}, "model": {"id": "claude-opus-5-5"}, "name": "a", "skills": [], "tools": [],
     "type": "agent", "updated_at": "2026-10-01T00:00:00Z", "version": 1
    """

    func testAgentDecodesBothExecutionIdentityShapes() throws {
        let aws = try decode(BetaManagedAgentsAgent.self, agentWire + #", "execution_identity": {"type": "aws_role", "role_arn": "arn:aws:iam::1:role/r"}}"#)
        guard case .awsRole(let role) = aws.executionIdentity else { return XCTFail("expected aws_role") }
        XCTAssertEqual(role.roleArn, "arn:aws:iam::1:role/r")
        let sa = try decode(BetaManagedAgentsAgent.self, agentWire + #", "execution_identity": {"type": "service_account"}}"#)
        guard case .serviceAccount = sa.executionIdentity else { return XCTFail("expected service_account") }
    }

    func testAnUnrecognizedExecutionIdentityDegradesAndAnAbsentOneIsNil() throws {
        guard case .unknown(let type, _) = try decode(BetaManagedAgentsAgent.self, agentWire + #", "execution_identity": {"type": "gcp_sa"}}"#).executionIdentity else {
            return XCTFail("expected .unknown")
        }
        XCTAssertEqual(type, "gcp_sa")
        XCTAssertNil(try decode(BetaManagedAgentsAgent.self, agentWire + "}").executionIdentity)
    }

    func testExecutionIdentityParamsEncode() throws {
        XCTAssertEqual(try encoded(BetaManagedAgentsExecutionIdentityParams.awsRole(roleArn: "arn:x")) as? NSDictionary,
                       ["type": "aws_role", "role_arn": "arn:x"])
        XCTAssertEqual(try encoded(BetaManagedAgentsExecutionIdentityParams.serviceAccount) as? NSDictionary,
                       ["type": "service_account"])
    }

    func testCreateAndUpdateSendTheIdentityOnlyWhenGiven() throws {
        let create = try XCTUnwrap(try encoded(BetaAgentCreateParams(
            model: .model("claude-opus-5-5"), name: "a", executionIdentity: .awsRole(roleArn: "arn:x")
        )) as? [String: Any])
        XCTAssertEqual((create["execution_identity"] as? [String: Any])?["role_arn"] as? String, "arn:x")
        let bare = try XCTUnwrap(try encoded(BetaAgentCreateParams(model: .model("claude-opus-5-5"), name: "a")) as? [String: Any])
        XCTAssertNil(bare["execution_identity"])

        // Update: omit to preserve; `.serviceAccount` restores the default.
        let restore = try XCTUnwrap(try encoded(BetaAgentUpdateParams(executionIdentity: .serviceAccount, version: 2)) as? [String: Any])
        XCTAssertEqual(restore["execution_identity"] as? NSDictionary, ["type": "service_account"])
        let untouched = try XCTUnwrap(try encoded(BetaAgentUpdateParams(name: "renamed", version: 2)) as? [String: Any])
        XCTAssertNil(untouched["execution_identity"], "omitting it must preserve the stored identity")
    }

    // MARK: - GitHub token

    func testGitHubRepositoryTokenIsOptionalForPublicRepos() throws {
        let publicRepo = try XCTUnwrap(try encoded(
            BetaManagedAgentsGitHubRepositoryResourceParams(url: "https://github.com/anthropics/anthropic-sdk-swift")
        ) as? [String: Any])
        XCTAssertNil(publicRepo["authorization_token"], "a public mount sends no token")
        XCTAssertEqual(publicRepo["type"] as? String, "github_repository")

        let privateRepo = try XCTUnwrap(try encoded(
            BetaManagedAgentsGitHubRepositoryResourceParams(authorizationToken: "ghp_x", url: "https://github.com/o/r")
        ) as? [String: Any])
        XCTAssertEqual(privateRepo["authorization_token"] as? String, "ghp_x")
    }

    // MARK: - threads statuses filter

    func testThreadsListSendsStatusesAsBracketedItems() async throws {
        var query: [URLQueryItem] = []
        MockURLProtocol.responder = { request in
            query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"])!
            return (response, Data(#"{"data": [], "next_page": null}"#.utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.sessions.threads.list(sessionId: "sesn_1", statuses: ["running", "idle"])
        XCTAssertEqual(query.filter { $0.name == "statuses[]" }.compactMap(\.value), ["running", "idle"])
    }
}
