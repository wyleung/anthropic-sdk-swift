import XCTest
@testable import Anthropic
@testable import AnthropicBeta

private struct ClosureTool: AnthropicTool {
    let name: String
    var description: String?
    let inputSchema: JSONValue = .object([:])
    let handler: @Sendable (JSONValue, ToolRunContext) async throws -> ToolOutput

    init(name: String, handler: @escaping @Sendable (JSONValue, ToolRunContext) async throws -> ToolOutput) {
        self.name = name
        self.handler = handler
    }

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput {
        try await handler(input, context)
    }
}

private struct PlainError: Error, CustomStringConvertible {
    var description: String { "boom" }
}

/// A mutable flag safe to capture in a `@Sendable` closure -- there's only ever one writer in these
/// tests (the closure itself, invoked at most once), so `@unchecked` is safe here.
private final class Flag: @unchecked Sendable {
    var value = false
}

/// Routes mock responses by HTTP method and path across the three endpoints `SessionToolRunner`
/// drives: GET `.../events/stream` (the live SSE connection), GET `.../events` (reconcile via
/// `events.list`), and POST `.../events` (`events.send`). A `NSLock` guards the recorded POST
/// bodies since the runner's stream loop and dispatch loop can call the mock from concurrent tasks.
private final class SessionRouter: @unchecked Sendable {
    var listFixture: Data
    var streamFixture: Data
    var sendFixture = #"{"data": []}"#.data(using: .utf8)!

    private let lock = NSLock()
    private var _sentBodies: [[String: Any]] = []

    init(listFixture: Data, streamFixture: Data) {
        self.listFixture = listFixture
        self.streamFixture = streamFixture
    }

    var sentBodies: [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return _sentBodies
    }

    func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let path = request.url?.path ?? ""
        let method = request.httpMethod ?? "GET"

        if method == "GET", path.hasSuffix("/stream") {
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, streamFixture)
        }
        if method == "GET" {
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, listFixture)
        }
        if method == "POST" {
            if let body = bodyData(from: request), let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                lock.lock()
                _sentBodies.append(object)
                lock.unlock()
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, sendFixture)
        }
        throw URLError(.unknown)
    }
}

final class BetaSessionToolRunnerTests: XCTestCase {
    // `SessionToolRunner` only holds an `unowned` reference to the client (via `BetaSessionEvents`),
    // so callers must keep it alive for as long as the runner runs -- hold it here rather than
    // letting it fall out of scope at the end of `makeRunner`.
    private var client: AnthropicClient?

    override func tearDown() {
        MockURLProtocol.responder = nil
        client = nil
        super.tearDown()
    }

    private static let emptyList = #"{"data": [], "next_page": null}"#.data(using: .utf8)!

    private static func list(_ events: String) -> Data {
        (#"{"data": ["# + events + #"], "next_page": null}"#).data(using: .utf8)!
    }

    private static func sse(_ events: [(event: String, data: String)]) -> Data {
        var lines: [String] = []
        for entry in events {
            lines.append("event: \(entry.event)")
            lines.append("data: \(entry.data)")
            lines.append("")
        }
        return (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
    }

    private func makeRunner(_ router: SessionRouter, tools: [AnyAnthropicTool] = []) -> SessionToolRunner {
        MockURLProtocol.responder = { try router.respond(to: $0) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        self.client = client
        return client.beta.sessions.events.toolRunner(sessionId: "sess_1", tools: tools, maxIdle: nil)
    }

    private func collectCalls(_ runner: SessionToolRunner) async throws -> [DispatchedToolCall] {
        var calls: [DispatchedToolCall] = []
        for try await call in await runner.run() {
            calls.append(call)
        }
        return calls
    }

    func testAllowedToolUseIsDispatchedAndResultPosted() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_1","name":"echo","input":{"value":"hi"},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"allow"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { input, _ in
            .text("echoed: \(input["value"]?.stringValue ?? "")")
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.toolUseId, "toolu_1")
        XCTAssertEqual(call.name, "echo")
        XCTAssertFalse(call.isError)
        XCTAssertTrue(call.posted)
        XCTAssertNil(call.confirmation)
        guard case .toolResult(let params) = call.result else {
            return XCTFail("expected .toolResult, got \(String(describing: call.result))")
        }
        XCTAssertEqual(params.toolUseId, "toolu_1")
        XCTAssertEqual(params.isError, false)
        guard case .text(let block) = params.content?.first else {
            return XCTFail("expected a .text content block")
        }
        XCTAssertEqual(block.text, "echoed: hi")

        XCTAssertEqual(router.sentBodies.count, 1)
        let sent = try XCTUnwrap(router.sentBodies.first)
        let events = try XCTUnwrap(sent["events"] as? [[String: Any]])
        XCTAssertEqual(events.first?["type"] as? String, "user.tool_result")
        XCTAssertEqual(events.first?["tool_use_id"] as? String, "toolu_1")
    }

    func testDeniedPermissionShortCircuitsWithoutDispatching() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_2","name":"echo","input":{},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"deny"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let invoked = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            invoked.value = true
            return .text("should not run")
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertNil(call.result)
        XCTAssertFalse(call.posted)
        XCTAssertEqual(call.confirmation, .deny)
        XCTAssertFalse(invoked.value)
        XCTAssertTrue(router.sentBodies.isEmpty)
    }

    func testAskPermissionHoldsUntilConfirmationAllows() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_3","name":"echo","input":{"value":"x"},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"ask"}"#
                ),
                (
                    "user.tool_confirmation",
                    #"{"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"toolu_3","result":"allow"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("done") })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.confirmation, .allow)
        XCTAssertTrue(call.posted)
        XCTAssertFalse(call.isError)
    }

    func testAskPermissionHoldsUntilConfirmationDenies() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_4","name":"echo","input":{},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"ask"}"#
                ),
                (
                    "user.tool_confirmation",
                    #"{"type":"user.tool_confirmation","id":"evt_conf","tool_use_id":"toolu_4","result":"deny"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let invoked = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            invoked.value = true
            return .text("should not run")
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertNil(call.result)
        XCTAssertFalse(call.posted)
        XCTAssertEqual(call.confirmation, .deny)
        XCTAssertFalse(invoked.value)
    }

    func testAlreadyAnsweredHistoryIsNotReExecuted() async throws {
        let router = SessionRouter(
            listFixture: Self.list(
                #"""
                {"type":"agent.tool_use","id":"toolu_5","name":"echo","input":{},"processed_at":"2026-01-01T00:00:00Z"},
                {"type":"user.tool_result","id":"evt_res","tool_use_id":"toolu_5"}
                """#
            ),
            streamFixture: Self.sse([
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#)
            ])
        )
        let invoked = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            invoked.value = true
            return .text("should not run")
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertTrue(calls.isEmpty)
        XCTAssertFalse(invoked.value)
        XCTAssertTrue(router.sentBodies.isEmpty)
    }

    func testSessionDeletedStopsTheRunnerCleanly() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                ("session.deleted", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#)
            ])
        )

        let calls = try await collectCalls(makeRunner(router))

        XCTAssertTrue(calls.isEmpty)
    }

    func testReconcileOnConnectCatchesUpOnUnansweredHistory() async throws {
        let router = SessionRouter(
            listFixture: Self.list(
                #"{"type":"agent.tool_use","id":"toolu_7","name":"echo","input":{"value":"y"},"processed_at":"2026-01-01T00:00:00Z"}"#
            ),
            streamFixture: Self.sse([
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#)
            ])
        )
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { input, _ in
            .text("echoed: \(input["value"]?.stringValue ?? "")")
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.toolUseId, "toolu_7")
        XCTAssertTrue(call.posted)
        XCTAssertEqual(router.sentBodies.count, 1)
    }

    func testUnknownToolNameProducesANotFoundErrorResult() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_8","name":"mystery","input":{},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"allow"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )

        let calls = try await collectCalls(makeRunner(router))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertTrue(call.isError)
        XCTAssertTrue(call.posted)
        guard case .toolResult(let params) = call.result, case .text(let block) = params.content?.first else {
            return XCTFail("expected a .toolResult with a .text content block, got \(String(describing: call.result))")
        }
        XCTAssertEqual(block.text, "Error: Tool 'mystery' not found")
        XCTAssertEqual(params.isError, true)
    }

    func testThrownToolErrorIsUsedVerbatim() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_9","name":"failing","input":{},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"allow"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let tool = AnyAnthropicTool(ClosureTool(name: "failing") { _, _ in
            throw ToolError("custom failure")
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        let call = try XCTUnwrap(calls.first)
        XCTAssertTrue(call.isError)
        guard case .toolResult(let params) = call.result, case .text(let block) = params.content?.first else {
            return XCTFail("expected a .toolResult with a .text content block, got \(String(describing: call.result))")
        }
        XCTAssertEqual(block.text, "custom failure")
    }

    func testThrownArbitraryErrorIsRenderedViaItsDescription() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.tool_use",
                    #"{"type":"agent.tool_use","id":"toolu_10","name":"failing","input":{},"processed_at":"2026-01-01T00:00:00Z","evaluated_permission":"allow"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let tool = AnyAnthropicTool(ClosureTool(name: "failing") { _, _ in
            throw PlainError()
        })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        let call = try XCTUnwrap(calls.first)
        XCTAssertTrue(call.isError)
        guard case .toolResult(let params) = call.result, case .text(let block) = params.content?.first else {
            return XCTFail("expected a .toolResult with a .text content block, got \(String(describing: call.result))")
        }
        XCTAssertEqual(block.text, String(describing: PlainError()))
    }

    func testCustomToolUseIsPostedAsUserCustomToolResult() async throws {
        let router = SessionRouter(
            listFixture: Self.emptyList,
            streamFixture: Self.sse([
                (
                    "agent.custom_tool_use",
                    #"{"type":"agent.custom_tool_use","id":"ctu_1","name":"custom_echo","input":{},"processed_at":"2026-01-01T00:00:00Z"}"#
                ),
                ("session.status_terminated", #"{"id":"evt_end","processed_at":"2026-01-01T00:00:01Z"}"#),
            ])
        )
        let tool = AnyAnthropicTool(ClosureTool(name: "custom_echo") { _, _ in .text("custom-done") })

        let calls = try await collectCalls(makeRunner(router, tools: [tool]))

        XCTAssertEqual(calls.count, 1)
        let call = try XCTUnwrap(calls.first)
        XCTAssertEqual(call.toolUseId, "ctu_1")
        XCTAssertNil(call.confirmation)
        guard case .customToolResult(let params) = call.result else {
            return XCTFail("expected .customToolResult, got \(String(describing: call.result))")
        }
        XCTAssertEqual(params.customToolUseId, "ctu_1")

        XCTAssertEqual(router.sentBodies.count, 1)
        let sent = try XCTUnwrap(router.sentBodies.first)
        let events = try XCTUnwrap(sent["events"] as? [[String: Any]])
        XCTAssertEqual(events.first?["type"] as? String, "user.custom_tool_result")
        XCTAssertEqual(events.first?["custom_tool_use_id"] as? String, "ctu_1")
        XCTAssertNil(events.first?["tool_use_id"])
    }
}
