import XCTest
@testable import Anthropic
@testable import AnthropicBeta

private struct WeatherTool: AnthropicTool {
    let name = "get_weather"
    let description: String? = "Current weather for a city."
    let inputSchema: JSONValue = .object(["type": .string("object")])

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput { "sunny" }
}

/// A tool defined once for `BetaToolRunner` can be handed to a request you send yourself.
final class BetaToolDeclarationTests: XCTestCase {
    private var client: AnthropicClient?

    override func tearDown() {
        MockURLProtocol.responder = nil
        client = nil
        super.tearDown()
    }

    func testTheEntryIsTheSameDeclarationTheRunnerSends() {
        let entry = BetaToolUnionParam(WeatherTool())

        XCTAssertEqual(entry, BetaToolUnionParam(AnyAnthropicTool(WeatherTool())))
        XCTAssertEqual(entry, .tool(.custom(AnyAnthropicTool(WeatherTool()).toolParam)))
    }

    func testItGoesStraightIntoBetaCreateAndCountTokens() async throws {
        var bodies: [String: [String: Any]] = [:]
        MockURLProtocol.responder = { request in
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(bodyData(from: request))) as? [String: Any])
            bodies[request.url?.path ?? ""] = body
            let json = request.url?.path == "/v1/messages/count_tokens"
                ? #"{"input_tokens": 3}"#
                : #"{"id":"msg_1","type":"message","role":"assistant","model":"m","content":[],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}"#
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        self.client = client
        let tools = [BetaToolUnionParam(WeatherTool())]

        _ = try await client.beta.messages.create(
            BetaMessageCreateParams(model: "m", maxTokens: 16, messages: [.user("Hi")], tools: tools)
        )
        _ = try await client.beta.messages.countTokens(
            BetaMessageCountTokensParams(model: "m", messages: [.user("Hi")], tools: tools)
        )

        for path in ["/v1/messages", "/v1/messages/count_tokens"] {
            let sent = (bodies[path]?["tools"] as? [[String: Any]])?.first
            XCTAssertEqual(sent?["name"] as? String, "get_weather", path)
            XCTAssertEqual(sent?["description"] as? String, "Current weather for a city.", path)
            XCTAssertEqual((sent?["input_schema"] as? [String: Any])?["type"] as? String, "object", path)
        }
    }
}
