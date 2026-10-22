import XCTest
@testable import Anthropic

final class MessagesCountTokensTests: XCTestCase {
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

    /// Serves `json` for any request and records what was sent.
    private func countTokens(
        respondingWith json: String = #"{"input_tokens": 2095}"#,
        statusCode: Int = 200,
        _ params: MessageCountTokensParams,
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> (MessageTokensCount, Captured) {
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
                url: request.url!, statusCode: statusCode, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let count = try await client.messages.countTokens(params, userProfileId: userProfileId, options: options)
        return (count, captured)
    }

    func testPostsToCountTokensAndDecodesInputTokens() async throws {
        let (count, captured) = try await countTokens(
            MessageCountTokensParams(model: "claude-opus-5-5", messages: [.user("Hello, Claude")])
        )

        XCTAssertEqual(count.inputTokens, 2095)
        XCTAssertEqual(captured.method, "POST")
        XCTAssertEqual(captured.path, "/v1/messages/count_tokens")
        XCTAssertNil(captured.query, "GA count_tokens takes no beta query flag")
        XCTAssertEqual(captured.headers["x-api-key"], "test-key")
        XCTAssertEqual(captured.body["model"] as? String, "claude-opus-5-5")
        XCTAssertEqual((captured.body["messages"] as? [[String: Any]])?.first?["role"] as? String, "user")
    }

    func testBodyCarriesOnlyTheFieldsThatAffectTheCount() async throws {
        let (_, captured) = try await countTokens(
            MessageCountTokensParams(model: "claude-opus-5-5", messages: [.user("Hi")])
        )
        // No max_tokens / stop_sequences / metadata / stream: they don't exist on this endpoint, and
        // omitted optionals must be absent rather than null.
        XCTAssertEqual(Set(captured.body.keys), ["model", "messages"])
    }

    func testEveryOptionalFieldIsSentWhenSet() async throws {
        let (_, captured) = try await countTokens(MessageCountTokensParams(
            model: "claude-opus-5-5",
            messages: [.user("Hi")],
            cacheControl: CacheControlEphemeral(ttl: .oneHour),
            outputConfig: OutputConfigParam(effort: nil, format: nil),
            speed: .fast,
            system: .text("be brief"),
            thinking: .betweenTools(ThinkingConfigBetweenToolsParam()),
            toolChoice: .auto(ToolChoiceAutoParam()),
            tools: [.custom(ToolParam(name: "get_stock_price", inputSchema: .object(["type": .string("object")])))]
        ))

        XCTAssertEqual(
            Set(captured.body.keys),
            ["model", "messages", "cache_control", "output_config", "speed", "system", "thinking", "tool_choice", "tools"]
        )
        XCTAssertEqual(captured.body["speed"] as? String, "fast")
        XCTAssertEqual(captured.body["system"] as? String, "be brief")
        XCTAssertEqual((captured.body["thinking"] as? [String: Any])?["type"] as? String, "between_tools")
        XCTAssertEqual((captured.body["tool_choice"] as? [String: Any])?["type"] as? String, "auto")
        XCTAssertEqual((captured.body["cache_control"] as? [String: Any])?["ttl"] as? String, "1h")
        XCTAssertEqual((captured.body["tools"] as? [[String: Any]])?.first?["name"] as? String, "get_stock_price")
    }

    func testServerToolsFromTheSharedUnionAreAccepted() async throws {
        // Python's `MessageCountTokensToolParam` is the same 21-member union as `ToolUnionParam`, so
        // server tools (and the new web-fetch `url_sources`) must work here too.
        let (_, captured) = try await countTokens(MessageCountTokensParams(
            model: "claude-opus-5-5", messages: [.user("Fetch it")],
            tools: [.webFetch20260318(WebFetchTool20260318Param(urlSources: WebFetchURLSourcesParam(userInput: .all)))]
        ))
        let tool = try XCTUnwrap((captured.body["tools"] as? [[String: Any]])?.first)
        XCTAssertEqual(tool["type"] as? String, "web_fetch_20260318")
        XCTAssertEqual(((tool["url_sources"] as? [String: Any])?["user_input"] as? [String: Any])?["type"] as? String, "all")
    }

    func testUserProfileIdAndWorkspaceIdAreHeadersNotBodyFields() async throws {
        let (_, captured) = try await countTokens(
            MessageCountTokensParams(model: "claude-opus-5-5", messages: [.user("Hi")]),
            userProfileId: "uprof_1",
            options: RequestOptions(workspaceId: "wrkspc_1")
        )
        XCTAssertEqual(captured.headers["anthropic-user-profile-id"], "uprof_1")
        XCTAssertEqual(captured.headers["anthropic-workspace-id"], "wrkspc_1")
        XCTAssertNil(captured.body["user_profile_id"])
        XCTAssertNil(captured.body["workspace_id"])
    }

    func testNoProfileOrWorkspaceHeaderIsSentByDefault() async throws {
        let (_, captured) = try await countTokens(MessageCountTokensParams(model: "m", messages: [.user("Hi")]))
        XCTAssertNil(captured.headers["anthropic-user-profile-id"])
        XCTAssertNil(captured.headers["anthropic-workspace-id"])
    }

    func testAnAPIErrorSurfacesAsTheUsualTypedError() async throws {
        do {
            _ = try await countTokens(
                respondingWith: #"{"type":"error","error":{"type":"invalid_request_error","message":"messages: required"}}"#,
                statusCode: 400,
                MessageCountTokensParams(model: "m", messages: [])
            )
            XCTFail("expected badRequest")
        } catch AnthropicError.badRequest(let detail) {
            XCTAssertEqual(detail.message, "messages: required")
        }
    }
}
