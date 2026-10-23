import XCTest
@testable import Anthropic

private struct WeatherTool: AnthropicTool {
    let name = "get_weather"
    let description: String? = "Current weather for a city."
    let inputSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object(["city": .object(["type": .string("string")])]),
        "required": .array([.string("city")]),
    ])

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput { "sunny" }
}

/// A tool defined once for `ToolRunner` can be handed to a request you send yourself.
final class ToolDeclarationTests: XCTestCase {
    private var client: AnthropicClient?

    override func tearDown() {
        MockURLProtocol.responder = nil
        client = nil
        super.tearDown()
    }

    private let expectedWire: NSDictionary = [
        "type": "custom",
        "name": "get_weather",
        "description": "Current weather for a city.",
        "input_schema": [
            "type": "object",
            "properties": ["city": ["type": "string"]],
            "required": ["city"],
        ],
    ]

    func testTheEntryIsTheSameDeclarationTheRunnerSends() throws {
        let entry = ToolUnionParam(WeatherTool())

        XCTAssertEqual(entry, ToolUnionParam(AnyAnthropicTool(WeatherTool())))
        XCTAssertEqual(entry, .custom(AnyAnthropicTool(WeatherTool()).toolParam))
        let wire = try JSONSerialization.jsonObject(with: HTTPTransport.encoder.encode(entry)) as? NSDictionary
        XCTAssertEqual(wire, expectedWire)
    }

    private func sentBody(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(bodyData(from: request))) as? [String: Any])
    }

    func testItGoesStraightIntoCreateAndCountTokens() async throws {
        var bodies: [String: [String: Any]] = [:]
        MockURLProtocol.responder = { request in
            bodies[request.url?.path ?? ""] = try self.sentBody(request)
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
        let tools = [ToolUnionParam(WeatherTool())]

        _ = try await client.messages.create(
            MessageCreateParams(model: "m", maxTokens: 16, messages: [.user("Hi")], tools: tools)
        )
        _ = try await client.messages.countTokens(MessageCountTokensParams(model: "m", messages: [.user("Hi")], tools: tools))

        for path in ["/v1/messages", "/v1/messages/count_tokens"] {
            let sent = (bodies[path]?["tools"] as? [NSDictionary])?.first
            XCTAssertEqual(sent, expectedWire, path)
        }
    }
}
