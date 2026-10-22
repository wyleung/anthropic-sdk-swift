import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMessagesCountTokensTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private struct Captured {
        var method: String?
        var path: String?
        var query: String?
        var headers: [String: String] = [:]
        var body: [String: Any] = [:]
    }

    private func countTokens(
        respondingWith json: String = #"{"input_tokens": 2095}"#,
        _ params: BetaMessageCountTokensParams,
        betas: [String] = [],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> (BetaMessageTokensCount, Captured) {
        var captured = Captured()
        MockURLProtocol.responder = { request in
            captured.method = request.httpMethod
            captured.path = request.url?.path
            captured.query = request.url?.query
            captured.headers = request.allHTTPHeaderFields ?? [:]
            if let data = bodyData(from: request),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                captured.body = object
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let count = try await client.beta.messages.countTokens(
            params, betas: betas, userProfileId: userProfileId, options: options
        )
        return (count, captured)
    }

    private let minimal = BetaMessageCountTokensParams(model: "claude-opus-5-5", messages: [.user("Hello, Claude")])

    func testPostsToCountTokensWithTheBetaQueryFlagAndDecodesInputTokens() async throws {
        let (count, captured) = try await countTokens(minimal)
        XCTAssertEqual(count.inputTokens, 2095)
        XCTAssertNil(count.contextManagement)
        XCTAssertEqual(captured.method, "POST")
        XCTAssertEqual(captured.path, "/v1/messages/count_tokens")
        XCTAssertEqual(captured.query, "beta=true")
    }

    func testTokenCountingBetaIsAlwaysSentEvenWithNoBetasGiven() async throws {
        let (_, captured) = try await countTokens(minimal)
        XCTAssertEqual(captured.headers["anthropic-beta"], "token-counting-2024-11-01")
    }

    func testRequiredBetaIsAppendedAfterCallerBetasAndNotDuplicated() async throws {
        let (_, appended) = try await countTokens(minimal, betas: ["fast-mode-2026-02-01", "files-api-2025-04-14"])
        XCTAssertEqual(
            appended.headers["anthropic-beta"], "fast-mode-2026-02-01,files-api-2025-04-14,token-counting-2024-11-01"
        )
        let (_, alreadyThere) = try await countTokens(minimal, betas: ["token-counting-2024-11-01"])
        XCTAssertEqual(alreadyThere.headers["anthropic-beta"], "token-counting-2024-11-01")
    }

    func testDecodesContextManagementOriginalInputTokens() async throws {
        let (count, _) = try await countTokens(
            respondingWith: #"{"input_tokens": 100, "context_management": {"original_input_tokens": 250}}"#, minimal
        )
        XCTAssertEqual(count.inputTokens, 100)
        XCTAssertEqual(count.contextManagement?.originalInputTokens, 250)
    }

    func testBodyCarriesBetaOnlyFieldsAndNothingThatDoesNotAffectTheCount() async throws {
        let (_, captured) = try await countTokens(BetaMessageCountTokensParams(
            model: "claude-opus-5-5",
            messages: [.user("Hi")],
            contextManagement: .object(["edits": .array([.object(["type": .string("clear_tool_uses_20250919")])])]),
            mcpServers: [BetaRequestMCPServerURLDefinitionParam(name: "docs", url: "https://mcp.example/sse")],
            speed: .fast,
            system: .text("be brief"),
            tools: [.mcpToolset(BetaMCPToolsetParam(mcpServerName: "docs"))]
        ))

        XCTAssertEqual(
            Set(captured.body.keys), ["model", "messages", "context_management", "mcp_servers", "speed", "system", "tools"]
        )
        XCTAssertEqual((captured.body["mcp_servers"] as? [[String: Any]])?.first?["name"] as? String, "docs")
        XCTAssertEqual((captured.body["tools"] as? [[String: Any]])?.first?["type"] as? String, "mcp_toolset")
        XCTAssertEqual(captured.body["speed"] as? String, "fast")
        let edit = ((captured.body["context_management"] as? [String: Any])?["edits"] as? [[String: Any]])?.first
        XCTAssertEqual(edit?["type"] as? String, "clear_tool_uses_20250919")
    }

    func testUserProfileIdAndWorkspaceIdAreHeaders() async throws {
        let (_, captured) = try await countTokens(
            minimal, userProfileId: "uprof_1", options: RequestOptions(workspaceId: "wrkspc_1")
        )
        XCTAssertEqual(captured.headers["anthropic-user-profile-id"], "uprof_1")
        XCTAssertEqual(captured.headers["anthropic-workspace-id"], "wrkspc_1")
        XCTAssertEqual(captured.headers["anthropic-beta"], "token-counting-2024-11-01")
    }
}
