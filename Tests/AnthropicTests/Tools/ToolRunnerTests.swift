import XCTest
@testable import Anthropic

private struct ClosureTool: AnthropicTool {
    let name: String
    var description: String?
    let inputSchema: JSONValue
    let handler: @Sendable (JSONValue, ToolRunContext) async throws -> ToolOutput

    init(
        name: String,
        description: String? = nil,
        inputSchema: JSONValue = .object([:]),
        handler: @escaping @Sendable (JSONValue, ToolRunContext) async throws -> ToolOutput
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.handler = handler
    }

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput {
        try await handler(input, context)
    }
}

private struct PlainError: Error, CustomStringConvertible {
    var description: String { "boom" }
}

/// A mutable flag safe to capture in a `@Sendable` closure -- there's only ever one writer in
/// these tests (the closure itself, invoked at most once), so `@unchecked` is safe here.
private final class Flag: @unchecked Sendable {
    var value = false
}

/// Replays a fixed sequence of JSON response bodies, one per call, and records each request's
/// decoded JSON body for later assertions -- `create()` uses `URLSession.data(for:)`, so
/// `request.httpBody` is populated directly (no `httpBodyStream` workaround needed, unlike the
/// streaming tests).
private final class SequencedResponder {
    private var fixtures: [Data]
    private(set) var requestBodies: [[String: Any]] = []

    init(_ fixtures: [Data]) {
        self.fixtures = fixtures
    }

    /// `URLProtocol` delivers the request body via `httpBodyStream`, not `httpBody`, once the
    /// request has passed through `URLSession` -- even for the non-streaming `data(for:)` path.
    private func bodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            guard bytesRead > 0 else { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }

    func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        if let httpBody = bodyData(from: request),
           let object = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] {
            requestBodies.append(object)
        }
        guard !fixtures.isEmpty else {
            throw URLError(.unknown)
        }
        let fixture = fixtures.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, fixture)
    }
}

final class ToolRunnerTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static func messageFixture(id: String, content: String, stopReason: String) -> Data {
        """
        {
            "id": "\(id)", "type": "message", "role": "assistant", "model": "claude-opus-5",
            "content": \(content),
            "stop_reason": "\(stopReason)", "stop_sequence": null,
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """.data(using: .utf8)!
    }

    private func makeRunner(
        responder: SequencedResponder,
        tools: [AnyAnthropicTool],
        maxIterations: Int? = nil
    ) -> ToolRunner {
        MockURLProtocol.responder = { try responder.respond(to: $0) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let params = MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
        return ToolRunner(client: client, params: params, tools: tools, maxIterations: maxIterations)
    }

    func testSingleToolCallRoundTrip() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {"value": "hi"}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "Done!"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { input, context in
            XCTAssertEqual(context.toolUseId, "toolu_1")
            XCTAssertEqual(context.toolName, "echo")
            XCTAssertEqual(input["value"]?.stringValue, "hi")
            return .text("echoed: hi")
        })
        let runner = makeRunner(responder: responder, tools: [tool])

        let finalMessage = try await runner.run()

        XCTAssertEqual(finalMessage.id, "msg_2")
        XCTAssertEqual(finalMessage.stopReason, .endTurn)
        XCTAssertEqual(responder.requestBodies.count, 2)

        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        XCTAssertEqual(secondRequestMessages.count, 3)

        let assistantMessage = secondRequestMessages[1]
        XCTAssertEqual(assistantMessage["role"] as? String, "assistant")
        let assistantContent = try XCTUnwrap(assistantMessage["content"] as? [[String: Any]])
        XCTAssertEqual(assistantContent.first?["type"] as? String, "tool_use")
        XCTAssertEqual(assistantContent.first?["id"] as? String, "toolu_1")

        let toolResultMessage = secondRequestMessages[2]
        XCTAssertEqual(toolResultMessage["role"] as? String, "user")
        let toolResultContent = try XCTUnwrap(toolResultMessage["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent.count, 1)
        XCTAssertEqual(toolResultContent[0]["type"] as? String, "tool_result")
        XCTAssertEqual(toolResultContent[0]["tool_use_id"] as? String, "toolu_1")
        XCTAssertEqual(toolResultContent[0]["content"] as? String, "echoed: hi")
        XCTAssertNil(toolResultContent[0]["is_error"])
    }

    func testRefusalStopsWithoutExecutingTools() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "refusal"
            ),
        ])
        let toolWasCalled = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            toolWasCalled.value = true
            return .text("should never run")
        })
        let runner = makeRunner(responder: responder, tools: [tool])

        let finalMessage = try await runner.run()

        XCTAssertEqual(finalMessage.stopReason, .refusal)
        XCTAssertFalse(toolWasCalled.value)
        XCTAssertEqual(responder.requestBodies.count, 1)
    }

    func testNoToolUseBlocksStopsAfterOneIteration() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: #"[{"type": "text", "text": "Hi there"}]"#, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, tools: [])

        let finalMessage = try await runner.run()

        XCTAssertEqual(finalMessage.id, "msg_1")
        XCTAssertEqual(responder.requestBodies.count, 1)
    }

    func testUnknownToolNameProducesNotFoundError() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "missing", "input": {}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, tools: [])

        _ = try await runner.run()

        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let toolResultContent = try XCTUnwrap(secondRequestMessages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent[0]["content"] as? String, "Error: Tool 'missing' not found")
        XCTAssertEqual(toolResultContent[0]["is_error"] as? Bool, true)
    }

    func testThrownToolErrorUsedVerbatim() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            throw ToolError("invalid input: missing 'value'")
        })
        let runner = makeRunner(responder: responder, tools: [tool])

        _ = try await runner.run()

        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let toolResultContent = try XCTUnwrap(secondRequestMessages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent[0]["content"] as? String, "invalid input: missing 'value'")
        XCTAssertEqual(toolResultContent[0]["is_error"] as? Bool, true)
    }

    func testThrownArbitraryErrorRenderedViaDescription() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            throw PlainError()
        })
        let runner = makeRunner(responder: responder, tools: [tool])

        _ = try await runner.run()

        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let toolResultContent = try XCTUnwrap(secondRequestMessages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent[0]["content"] as? String, String(describing: PlainError()))
        XCTAssertEqual(toolResultContent[0]["is_error"] as? Bool, true)
    }

    func testConcurrentToolCallsBatchedInOriginalOrder() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: """
                [
                    {"type": "tool_use", "id": "toolu_1", "name": "slow", "input": {}},
                    {"type": "tool_use", "id": "toolu_2", "name": "fast", "input": {}},
                    {"type": "tool_use", "id": "toolu_3", "name": "medium", "input": {}}
                ]
                """,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tools = [
            AnyAnthropicTool(ClosureTool(name: "slow") { _, _ in
                try await Task.sleep(nanoseconds: 30_000_000)
                return .text("slow-result")
            }),
            AnyAnthropicTool(ClosureTool(name: "fast") { _, _ in .text("fast-result") }),
            AnyAnthropicTool(ClosureTool(name: "medium") { _, _ in
                try await Task.sleep(nanoseconds: 10_000_000)
                return .text("medium-result")
            }),
        ]
        let runner = makeRunner(responder: responder, tools: tools)

        _ = try await runner.run()

        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let toolResultContent = try XCTUnwrap(secondRequestMessages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent.map { $0["tool_use_id"] as? String }, ["toolu_1", "toolu_2", "toolu_3"])
        XCTAssertEqual(toolResultContent.map { $0["content"] as? String }, ["slow-result", "fast-result", "medium-result"])
    }

    func testHooksFireAsExpected() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let runner = makeRunner(responder: responder, tools: [tool])

        var beforeRequestCallCount = 0
        var appendedMessageBatches: [[MessageParam]] = []
        var toolCallResponseWasRewritten = false

        runner.beforeRequest = { params in
            beforeRequestCallCount += 1
            return params
        }
        runner.onAppendMessages = { appended in
            appendedMessageBatches.append(appended)
        }
        runner.onToolCallResponse = { message in
            toolCallResponseWasRewritten = true
            return message
        }

        _ = try await runner.run()

        XCTAssertEqual(beforeRequestCallCount, 2)
        XCTAssertEqual(appendedMessageBatches.count, 1)
        XCTAssertEqual(appendedMessageBatches.first?.count, 2)
        XCTAssertTrue(toolCallResponseWasRewritten)
    }

    func testMaxIterationsStopsTheLoopEarly() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use"
            ),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let runner = makeRunner(responder: responder, tools: [tool], maxIterations: 1)

        let finalMessage = try await runner.run()

        XCTAssertEqual(finalMessage.id, "msg_1")
        XCTAssertEqual(responder.requestBodies.count, 1)
    }
}
