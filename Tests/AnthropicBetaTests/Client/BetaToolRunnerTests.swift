import XCTest
@testable import Anthropic
@testable import AnthropicBeta

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
/// decoded JSON body for later assertions.
private final class SequencedResponder {
    private var fixtures: [Data]
    private(set) var requestBodies: [[String: Any]] = []

    init(_ fixtures: [Data]) {
        self.fixtures = fixtures
    }

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

/// Records the size of every batch passed to `onAppendMessages`.
private final class BatchLog: @unchecked Sendable {
    private(set) var counts: [Int] = []

    func add(_ count: Int) {
        counts.append(count)
    }
}

/// Lets a tool body or a hook reach the runner it runs in; assigned once, right after the runner exists.
private final class RunnerBox: @unchecked Sendable {
    var runner: BetaToolRunner?
}

/// Records message ids passed to a hook.
private final class IDLog: @unchecked Sendable {
    private(set) var ids: [String] = []

    func add(_ id: String) {
        ids.append(id)
    }
}

final class BetaToolRunnerTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static func messageFixture(
        id: String, content: String, stopReason: String, container: String? = nil
    ) -> Data {
        let containerField = container.map { ", \"container\": \($0)" } ?? ""
        return """
        {
            "id": "\(id)", "type": "message", "role": "assistant", "model": "claude-opus-5",
            "content": \(content),
            "stop_reason": "\(stopReason)", "stop_sequence": null,
            "usage": {"input_tokens": 10, "output_tokens": 5}\(containerField)
        }
        """.data(using: .utf8)!
    }

    private func makeRunner(
        responder: SequencedResponder,
        tools: [AnyAnthropicTool],
        messages: [BetaMessageParam] = [.user("Hi")],
        container: MessageCreateParamsContainerParam? = nil,
        maxIterations: Int? = nil
    ) -> BetaToolRunner {
        MockURLProtocol.responder = { try responder.respond(to: $0) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let params = BetaMessageCreateParams(
            model: "claude-opus-5", maxTokens: 256, messages: messages, container: container
        )
        return BetaToolRunner(client: client, params: params, tools: tools, maxIterations: maxIterations)
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

    /// Only `tool_use` runs tools. Every other finished turn stops with its `tool_use` blocks unrun: a
    /// `max_tokens` turn can end in a truncated call, and none of the others asked for a result.
    func testOnlyAToolUseTurnRunsToolsEveryOtherStopReasonStopsWithoutRunningThem() async throws {
        for stopReason in ["end_turn", "max_tokens", "stop_sequence", "model_context_window_exceeded", "refusal", "a_reason_from_the_future"] {
            let responder = SequencedResponder([
                Self.messageFixture(
                    id: "msg_1",
                    content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                    stopReason: stopReason
                ),
            ])
            let toolWasCalled = Flag()
            let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
                toolWasCalled.value = true
                return .text("should never run")
            })

            let finalMessage = try await makeRunner(responder: responder, tools: [tool]).run()

            XCTAssertEqual(finalMessage.id, "msg_1", stopReason)
            XCTAssertFalse(toolWasCalled.value, "\(stopReason) must not run the tool")
            XCTAssertEqual(responder.requestBodies.count, 1, stopReason)
        }
    }

    /// `pause_turn` (a server tool hit its iteration limit) and `compaction` (compaction handed the turn
    /// back before the model answered) are unfinished turns: the server expects them back unchanged to
    /// carry on. The runner used to end the run at both.
    func testPausedAndCompactionTurnsAreSentBackUnchangedAndTheRunContinues() async throws {
        for stopReason in ["pause_turn", "compaction"] {
            let first = #"[{"type": "server_tool_use", "id": "srvtoolu_1", "name": "web_search", "input": {"query": "x"}}]"#
            let responder = SequencedResponder([
                Self.messageFixture(id: "msg_1", content: first, stopReason: stopReason),
                Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "Done!"}]"#, stopReason: "end_turn"),
            ])
            let appended = BatchLog()
            let runner = makeRunner(responder: responder, tools: [])
            runner.onAppendMessages = { appended.add($0.count) }

            let finalMessage = try await runner.run()

            XCTAssertEqual(finalMessage.id, "msg_2", stopReason)
            XCTAssertEqual(responder.requestBodies.count, 2, stopReason)
            let second = try XCTUnwrap(responder.requestBodies.dropFirst().first, "\(stopReason) must be sent back")
            let messages = try XCTUnwrap(second["messages"] as? [[String: Any]])
            XCTAssertEqual(messages.count, 2, "\(stopReason): the user turn, then the unfinished turn, nothing after it")
            XCTAssertEqual(messages.last?["role"] as? String, "assistant", stopReason)
            let content = try XCTUnwrap(messages.last?["content"] as? [[String: Any]])
            XCTAssertEqual(content.first?["id"] as? String, "srvtoolu_1", stopReason)
            XCTAssertEqual(appended.counts, [1], "\(stopReason): only the assistant turn, no tool results")
        }
    }

    func testPauseTurnRunsNoToolsEvenWhenItCarriesAToolUseBlock() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "pause_turn"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "Done!"}]"#, stopReason: "end_turn"),
        ])
        let toolWasCalled = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            toolWasCalled.value = true
            return .text("should never run")
        })

        let finalMessage = try await makeRunner(responder: responder, tools: [tool]).run()

        XCTAssertEqual(finalMessage.id, "msg_2")
        XCTAssertFalse(toolWasCalled.value)
    }

    // MARK: - Changing a run in flight: addTools / removeTools

    private static func toolUse(_ id: String, _ name: String) -> String {
        #"[{"type": "tool_use", "id": "\#(id)", "name": "\#(name)", "input": {}}]"#
    }

    private static let endTurnContent = #"[{"type": "text", "text": "Done!"}]"#
    private static let compactionContent = #"[{"type": "compaction", "content": "Summary.", "signature": "sig-1"}]"#

    private func makeRunner(
        responder: SequencedResponder, params: BetaMessageCreateParams, tools: [AnyAnthropicTool]
    ) -> BetaToolRunner {
        MockURLProtocol.responder = { try responder.respond(to: $0) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        return BetaToolRunner(client: client, params: params, tools: tools)
    }

    private var baseParams: BetaMessageCreateParams {
        BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
    }

    /// The `index`th request body, failing the test (rather than crashing) when it was never made.
    private func request(_ index: Int, of responder: SequencedResponder) throws -> [String: Any] {
        try XCTUnwrap(
            responder.requestBodies.indices.contains(index) ? responder.requestBodies[index] : nil,
            "request \(index + 1) was never made (\(responder.requestBodies.count) were)"
        )
    }

    private func messages(of body: [String: Any]) -> [[String: Any]] {
        body["messages"] as? [[String: Any]] ?? []
    }

    private func toolNames(of body: [String: Any]) -> [String] {
        (body["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
    }

    func testAddedFunctionToolRunsAtOnceAndTheModelIsToldBeforeTheNextRequest() async throws {
        let box = RunnerBox()
        let late = AnyAnthropicTool(ClosureTool(name: "late") { _, _ in .text("late ran") })
        let starter = AnyAnthropicTool(ClosureTool(name: "starter") { _, _ in
            box.runner?.addTools([late])
            return .text("added")
        })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_2", content: Self.toolUse("toolu_2", "late"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_3", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [starter])
        box.runner = runner

        let final = try await runner.run()

        XCTAssertEqual(final.id, "msg_3")
        XCTAssertEqual(responder.requestBodies.count, 3)
        for index in 0..<3 {
            XCTAssertEqual(toolNames(of: try request(index, of: responder)), ["starter"], "the tools param must not change")
        }
        XCTAssertFalse(messages(of: try request(0, of: responder)).contains { $0["role"] as? String == "system" })
        let told = try XCTUnwrap(messages(of: try request(1, of: responder)).last)
        XCTAssertEqual(told["role"] as? String, "system")
        let addition = try XCTUnwrap((told["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(addition["type"] as? String, "tool_addition")
        let tool = try XCTUnwrap(addition["tool"] as? [String: Any])
        XCTAssertEqual(tool["type"] as? String, "tool_definition")
        XCTAssertEqual((tool["definition"] as? [String: Any])?["name"] as? String, "late")
        // And the added tool really ran: its result is in the last request.
        let result = try XCTUnwrap((messages(of: try request(2, of: responder)).last?["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(result["tool_use_id"] as? String, "toolu_2")
        XCTAssertEqual(result["content"] as? String, "late ran")
    }

    func testRemovedToolStopsRunningAtOnceAndTheModelIsToldBeforeTheNextRequest() async throws {
        let box = RunnerBox()
        let echoWasCalled = Flag()
        let echo = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            echoWasCalled.value = true
            return .text("should never run")
        })
        let starter = AnyAnthropicTool(ClosureTool(name: "starter") { _, _ in
            box.runner?.removeTools(["echo"])
            return .text("removed")
        })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_2", content: Self.toolUse("toolu_2", "echo"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_3", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [starter, echo])
        box.runner = runner

        _ = try await runner.run()

        XCTAssertFalse(echoWasCalled.value)
        for index in 0..<3 {
            XCTAssertEqual(toolNames(of: try request(index, of: responder)), ["starter", "echo"], "the tools param must not change")
        }
        let told = try XCTUnwrap(messages(of: try request(1, of: responder)).last)
        XCTAssertEqual(told["role"] as? String, "system")
        let removal = try XCTUnwrap((told["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(removal["type"] as? String, "tool_removal")
        XCTAssertEqual((removal["tool"] as? [String: Any])?["type"] as? String, "tool_reference")
        XCTAssertEqual((removal["tool"] as? [String: Any])?["name"] as? String, "echo")
        let result = try XCTUnwrap((messages(of: try request(2, of: responder)).last?["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(result["is_error"] as? Bool, true)
        XCTAssertEqual(result["content"] as? String, "Error: Tool 'echo' not found")
    }

    func testAnAddedDefinitionIsNeverRunAndReplacesAFunctionToolOfTheSameName() async throws {
        let box = RunnerBox()
        let echoWasCalled = Flag()
        let echo = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            echoWasCalled.value = true
            return .text("should never run")
        })
        let starter = AnyAnthropicTool(ClosureTool(name: "starter") { _, _ in
            box.runner?.addTools(definitions: [.tool(.custom(ToolParam(name: "echo", inputSchema: .object([:]))))])
            return .text("redefined")
        })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_2", content: Self.toolUse("toolu_2", "echo"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_3", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [starter, echo])
        box.runner = runner

        _ = try await runner.run()

        XCTAssertFalse(echoWasCalled.value, "a raw definition is not runnable here, and it replaces the function tool")
        let told = try XCTUnwrap(messages(of: try request(1, of: responder)).last)
        let addition = try XCTUnwrap((told["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(addition["type"] as? String, "tool_addition")
        XCTAssertEqual(((addition["tool"] as? [String: Any])?["definition"] as? [String: Any])?["name"] as? String, "echo")
    }

    /// A turn that stopped on `pause_turn` is sent back to be continued, so it has to stay last: the
    /// changes wait for the request after it.
    func testToolChangesWaitOutAPausedTurn() async throws {
        let box = RunnerBox()
        let added = Flag()
        let late = AnyAnthropicTool(ClosureTool(name: "late") { _, _ in .text("late ran") })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.endTurnContent, stopReason: "pause_turn"),
            Self.messageFixture(id: "msg_2", content: Self.toolUse("toolu_2", "late"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_3", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [])
        box.runner = runner
        runner.onAppendMessages = { _ in
            guard !added.value else { return }
            added.value = true
            box.runner?.addTools([late])
        }

        _ = try await runner.run()

        let second = messages(of: try request(1, of: responder))
        XCTAssertEqual(second.map { $0["role"] as? String }, ["user", "assistant"], "the paused turn stays last")
        let third = messages(of: try request(2, of: responder))
        XCTAssertEqual(third.last?["role"] as? String, "system", "the changes go out with the request after it")
        XCTAssertEqual(((third.last?["content"] as? [[String: Any]])?.first)?["type"] as? String, "tool_addition")
    }

    // MARK: - Compaction

    private func compactionParams(
        contextManagement: JSONValue? = nil, stopSequences: [String]? = nil,
        toolChoice: ToolChoiceParam? = nil, outputConfig: BetaOutputConfigParam? = nil
    ) -> BetaMessageCreateParams {
        BetaMessageCreateParams(
            model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")],
            contextManagement: contextManagement, outputConfig: outputConfig,
            stopSequences: stopSequences, toolChoice: toolChoice
        )
    }

    func testCompactionRequestReplacesTheHistoryAndTheRunCarriesOn() async throws {
        let box = RunnerBox()
        let scheduled = Flag()
        let compacted = IDLog()
        let starter = AnyAnthropicTool(ClosureTool(name: "starter") { _, _ in .text("ok") })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_c", content: Self.compactionContent, stopReason: "compaction"),
            Self.messageFixture(id: "msg_3", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        let params = compactionParams(
            contextManagement: .object(["edits": .array([.object(["type": .string("clear_tool_uses_20250919")])])]),
            stopSequences: ["STOP"],
            toolChoice: .any(ToolChoiceAnyParam()),
            outputConfig: BetaOutputConfigParam(effort: .high, format: JSONOutputFormatParam(schema: .object([:])))
        )
        let runner = makeRunner(responder: responder, params: params, tools: [starter])
        box.runner = runner
        runner.onAppendMessages = { _ in
            guard !scheduled.value else { return }
            scheduled.value = true
            try? box.runner?.compactBeforeNextTurn()
        }
        runner.onCompaction = { compacted.add($0.id) }

        let final = try await runner.run()

        XCTAssertEqual(final.id, "msg_3", "run() returns the last turn, not the compaction")
        XCTAssertEqual(compacted.ids, ["msg_c"])
        XCTAssertEqual(responder.requestBodies.count, 3)

        let compaction = try request(1, of: responder)
        XCTAssertEqual((compaction["compaction"] as? [String: Any])?["type"] as? String, "summarize")
        XCTAssertEqual(messages(of: compaction).count, 3, "the whole conversation so far is what gets summarized")
        for key in ["context_management", "stop_sequences", "tool_choice"] {
            XCTAssertNil(compaction[key], "\(key) only shapes a reply, which a compaction request doesn't make")
        }
        XCTAssertEqual((compaction["output_config"] as? [String: Any])?["effort"] as? String, "high")
        XCTAssertNil((compaction["output_config"] as? [String: Any])?["format"])

        let next = try request(2, of: responder)
        XCTAssertNil(next["compaction"], "only the one request compacts")
        let history = messages(of: next)
        XCTAssertEqual(history.count, 1, "the summary replaces everything it summarizes")
        XCTAssertEqual(history.first?["role"] as? String, "assistant")
        let block = try XCTUnwrap((history.first?["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(block["type"] as? String, "compaction")
        XCTAssertEqual(block["signature"] as? String, "sig-1", "echoed back verbatim")
        for key in ["context_management", "stop_sequences", "tool_choice"] {
            XCTAssertNotNil(next[key], "\(key) is only dropped for the compaction request itself")
        }
        XCTAssertNotNil((next["output_config"] as? [String: Any])?["format"])
    }

    func testCompactionScheduledOnTheFinalTurnCompactsAfterAddingIt() async throws {
        let box = RunnerBox()
        let scheduled = Flag()
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.endTurnContent, stopReason: "end_turn"),
            Self.messageFixture(id: "msg_c", content: Self.compactionContent, stopReason: "compaction"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [])
        box.runner = runner
        runner.beforeRequest = { params in
            if !scheduled.value {
                scheduled.value = true
                try? box.runner?.compactBeforeNextTurn()
            }
            return params
        }

        let final = try await runner.run()

        XCTAssertEqual(final.id, "msg_1", "run() returns the answer, not the compaction")
        let compaction = try request(1, of: responder)
        XCTAssertEqual(messages(of: compaction).map { $0["role"] as? String }, ["user", "assistant"], "the final turn is summarized too")
        XCTAssertEqual(runner.messages.count, 1)
        guard case .compaction? = runner.messages.first?.content.first else { return XCTFail("history is not the compaction") }
    }

    func testPendingCompactionIsDroppedWhenTheFinalTurnEndedWithUnansweredToolCalls() async throws {
        let box = RunnerBox()
        let scheduled = Flag()
        let responder = SequencedResponder([
            // Cut off mid tool call: it is never run, and the API can't compact a conversation that ends so.
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "max_tokens"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [])
        box.runner = runner
        runner.beforeRequest = { params in
            if !scheduled.value {
                scheduled.value = true
                try? box.runner?.compactBeforeNextTurn()
            }
            return params
        }

        let final = try await runner.run()

        XCTAssertEqual(final.id, "msg_1")
        XCTAssertEqual(responder.requestBodies.count, 1, "no compaction request")
        XCTAssertEqual(runner.messages.count, 1, "the conversation is as it was")
    }

    func testCompactionWaitsForAPausedTurnToBeResumed() async throws {
        let box = RunnerBox()
        let scheduled = Flag()
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.endTurnContent, stopReason: "pause_turn"),
            Self.messageFixture(id: "msg_2", content: Self.endTurnContent, stopReason: "end_turn"),
            Self.messageFixture(id: "msg_c", content: Self.compactionContent, stopReason: "compaction"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [])
        box.runner = runner
        runner.onAppendMessages = { _ in
            guard !scheduled.value else { return }
            scheduled.value = true
            try? box.runner?.compactBeforeNextTurn()
        }

        let final = try await runner.run()

        XCTAssertEqual(final.id, "msg_2")
        XCTAssertNil(try request(1, of: responder)["compaction"], "the API can't compact a turn that ends mid-way")
        XCTAssertNotNil(try request(2, of: responder)["compaction"])
        XCTAssertEqual(messages(of: try request(2, of: responder)).count, 3)
    }

    func testACompactionWithoutASummaryLeavesTheConversationAlone() async throws {
        let box = RunnerBox()
        let scheduled = Flag()
        let compacted = IDLog()
        let starter = AnyAnthropicTool(ClosureTool(name: "starter") { _, _ in .text("ok") })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_c", content: #"[{"type": "compaction", "content": null}]"#, stopReason: "compaction"),
            Self.messageFixture(id: "msg_3", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        let runner = makeRunner(responder: responder, params: baseParams, tools: [starter])
        box.runner = runner
        runner.onAppendMessages = { _ in
            guard !scheduled.value else { return }
            scheduled.value = true
            try? box.runner?.compactBeforeNextTurn()
        }
        runner.onCompaction = { compacted.add($0.id) }

        let final = try await runner.run()

        XCTAssertEqual(final.id, "msg_3")
        XCTAssertEqual(compacted.ids, [])
        XCTAssertEqual(messages(of: try request(2, of: responder)).count, 3, "user, assistant, tool result: all still there")
    }

    func testToolsWithdrawnBeforeACompactionStayWithdrawnAfterIt() async throws {
        let box = RunnerBox()
        let scheduled = Flag()
        let echoWasCalled = Flag()
        let echo = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            echoWasCalled.value = true
            return .text("should never run")
        })
        let starter = AnyAnthropicTool(ClosureTool(name: "starter") { _, _ in .text("ok") })
        let responder = SequencedResponder([
            Self.messageFixture(id: "msg_1", content: Self.toolUse("toolu_1", "starter"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_c", content: Self.compactionContent, stopReason: "compaction"),
            Self.messageFixture(id: "msg_3", content: Self.toolUse("toolu_3", "echo"), stopReason: "tool_use"),
            Self.messageFixture(id: "msg_4", content: Self.endTurnContent, stopReason: "end_turn"),
        ])
        // The history withdraws `echo`, and that history is what the compaction is about to replace.
        let withdrawn = BetaMessageParam(
            role: .system,
            content: [.toolRemoval(BetaRequestToolRemovalBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo"))))]
        )
        let params = BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [withdrawn, .user("Hi")])
        let runner = makeRunner(responder: responder, params: params, tools: [starter, echo])
        box.runner = runner
        runner.onAppendMessages = { _ in
            guard !scheduled.value else { return }
            scheduled.value = true
            try? box.runner?.compactBeforeNextTurn()
        }

        _ = try await runner.run()

        XCTAssertFalse(echoWasCalled.value, "the summary replaced the removal block, not the removal")
        let result = try XCTUnwrap((messages(of: try request(3, of: responder)).last?["content"] as? [[String: Any]])?.first)
        XCTAssertEqual(result["content"] as? String, "Error: Tool 'echo' not found")
    }

    func testCompactionIsRefusedWhileContextManagementHasACompactionEdit() async throws {
        let responder = SequencedResponder([])
        let params = compactionParams(
            contextManagement: .object(["edits": .array([.object(["type": .string("compact_20260904")])])])
        )
        let runner = makeRunner(responder: responder, params: params, tools: [])

        XCTAssertThrowsError(try runner.compactBeforeNextTurn()) { error in
            guard case AnthropicError.invalidArgument(let message) = error else {
                return XCTFail("expected .invalidArgument, got \(error)")
            }
            XCTAssertTrue(message.contains("context_management"), message)
        }
    }

    func testACompactionParamOnTheRunnerIsRefusedBeforeAnyRequest() async throws {
        let responder = SequencedResponder([])
        let params = BetaMessageCreateParams(
            model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")], compaction: BetaCompactionConfigParam()
        )
        let runner = makeRunner(responder: responder, params: params, tools: [])

        do {
            _ = try await runner.run()
            XCTFail("every request in the loop would compact again")
        } catch AnthropicError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("compactBeforeNextTurn"), message)
        }
        XCTAssertEqual(responder.requestBodies.count, 0)
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
        var appendedMessageBatches: [[BetaMessageParam]] = []
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

    // MARK: - Beta-only: container propagation

    func testContainerIsFilledInWhenNoneWasPinned() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use",
                container: #"{"id": "cont_1", "expires_at": "2026-01-01T00:00:00Z", "skills": null}"#
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let runner = makeRunner(responder: responder, tools: [tool])

        _ = try await runner.run()

        XCTAssertEqual(responder.requestBodies[1]["container"] as? String, "cont_1")
    }

    func testPinnedContainerIdIsNeverClobbered() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use",
                container: #"{"id": "cont_from_server", "expires_at": "2026-01-01T00:00:00Z", "skills": null}"#
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let runner = makeRunner(responder: responder, tools: [tool], container: .id("pinned"))

        _ = try await runner.run()

        XCTAssertEqual(responder.requestBodies[1]["container"] as? String, "pinned")
    }

    func testContainerObjectWithNoIdIsFilledInWhilePreservingSkills() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use",
                container: #"{"id": "cont_new", "expires_at": "2026-01-01T00:00:00Z", "skills": null}"#
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let initialContainer = MessageCreateParamsContainerParam.container(
            ContainerParams(id: nil, skills: [SkillParams(skillId: "skill_1", type: .anthropic)])
        )
        let runner = makeRunner(responder: responder, tools: [tool], container: initialContainer)

        _ = try await runner.run()

        let container = try XCTUnwrap(responder.requestBodies[1]["container"] as? [String: Any])
        XCTAssertEqual(container["id"] as? String, "cont_new")
        let skills = try XCTUnwrap(container["skills"] as? [[String: Any]])
        XCTAssertEqual(skills.first?["skill_id"] as? String, "skill_1")
    }

    func testContainerObjectWithExistingIdIsNeverClobbered() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use",
                container: #"{"id": "cont_new", "expires_at": "2026-01-01T00:00:00Z", "skills": null}"#
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let initialContainer = MessageCreateParamsContainerParam.container(
            ContainerParams(id: "already_set", skills: nil)
        )
        let runner = makeRunner(responder: responder, tools: [tool], container: initialContainer)

        _ = try await runner.run()

        let container = try XCTUnwrap(responder.requestBodies[1]["container"] as? [String: Any])
        XCTAssertEqual(container["id"] as? String, "already_set")
    }

    // MARK: - Beta-only: tool availability tracking

    func testToolRemovalBlockMakesARegisteredToolUnavailable() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let toolWasCalled = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            toolWasCalled.value = true
            return .text("echoed")
        })
        let systemMessage = BetaMessageParam(
            role: .system,
            content: [.toolRemoval(BetaRequestToolRemovalBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo"))))]
        )
        let runner = makeRunner(responder: responder, tools: [tool], messages: [systemMessage, .user("Hi")])

        _ = try await runner.run()

        XCTAssertFalse(toolWasCalled.value)
        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let toolResultContent = try XCTUnwrap(secondRequestMessages.last?["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent[0]["content"] as? String, "Error: Tool 'echo' not found")
        XCTAssertEqual(toolResultContent[0]["is_error"] as? Bool, true)
    }

    func testToolAdditionAfterRemovalRestoresAvailability() async throws {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1",
                content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#,
                stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in .text("echoed") })
        let systemMessage = BetaMessageParam(
            role: .system,
            content: [
                .toolRemoval(BetaRequestToolRemovalBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo")))),
                .toolAddition(BetaRequestToolAdditionBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo")))),
            ]
        )
        let runner = makeRunner(responder: responder, tools: [tool], messages: [systemMessage, .user("Hi")])

        _ = try await runner.run()

        let secondRequestMessages = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let toolResultContent = try XCTUnwrap(secondRequestMessages.last?["content"] as? [[String: Any]])
        XCTAssertEqual(toolResultContent[0]["content"] as? String, "echoed")
        XCTAssertNil(toolResultContent[0]["is_error"])
    }

    // MARK: - inline tool definitions and compaction tool_changes

    private func runEchoTurn(messages: [BetaMessageParam]) async throws -> (toolWasCalled: Bool, result: [String: Any]) {
        let responder = SequencedResponder([
            Self.messageFixture(
                id: "msg_1", content: #"[{"type": "tool_use", "id": "toolu_1", "name": "echo", "input": {}}]"#, stopReason: "tool_use"
            ),
            Self.messageFixture(id: "msg_2", content: #"[{"type": "text", "text": "ok"}]"#, stopReason: "end_turn"),
        ])
        let called = Flag()
        let tool = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            called.value = true
            return .text("echoed")
        })
        let runner = makeRunner(responder: responder, tools: [tool], messages: messages)
        _ = try await runner.run()
        let second = try XCTUnwrap(responder.requestBodies[1]["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(second.last?["content"] as? [[String: Any]])
        return (called.value, content[0])
    }

    private func removeEcho() -> BetaContentBlockParam {
        .toolRemoval(BetaRequestToolRemovalBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo"))))
    }

    func testToolAdditionByDefinitionNamesTheToolSoItIsAvailableAgain() async throws {
        let system = BetaMessageParam(role: .system, content: [
            removeEcho(),
            .toolAddition(BetaRequestToolAdditionBlockParam(
                definition: .tool(.custom(ToolParam(name: "echo", inputSchema: .object(["type": .string("object")]))))
            )),
        ])
        let (called, result) = try await runEchoTurn(messages: [system, .user("Hi")])
        XCTAssertTrue(called, "a by-value definition carries the tool's name, so it re-adds the tool")
        XCTAssertEqual(result["content"] as? String, "echoed")
    }

    func testAnAdditionByDefinitionOfAnUnnamedToolsetIsIgnoredNotACrash() async throws {
        // An mcp_toolset has no `name`, so it can never name a locally runnable tool.
        let system = BetaMessageParam(role: .system, content: [
            removeEcho(),
            .toolAddition(BetaRequestToolAdditionBlockParam(definition: .mcpToolset(BetaMCPToolsetParam(mcpServerName: "docs")))),
        ])
        let (called, result) = try await runEchoTurn(messages: [system, .user("Hi")])
        XCTAssertFalse(called)
        XCTAssertEqual(result["is_error"] as? Bool, true)
    }

    func testACompactionBlocksToolChangesInAnAssistantMessageAreFolded() async throws {
        // After compaction the summarized system messages are gone; the block's tool_changes carry their
        // effect. Forgetting them would silently resurrect a tool the conversation had withdrawn.
        let assistant = BetaMessageParam(role: .assistant, content: [
            .compaction(BetaCompactionBlockParam(
                content: "summary", signature: "sig",
                toolChanges: [.removal(BetaRequestToolRemovalBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo"))))]
            )),
        ])
        let (called, result) = try await runEchoTurn(messages: [assistant, .user("Hi")])
        XCTAssertFalse(called)
        XCTAssertEqual(result["content"] as? String, "Error: Tool 'echo' not found")
    }

    func testCompactionToolChangesEchoedVerbatimFromAResponseAreFoldedToo() async throws {
        // The shape a response block's tool_changes take after `asRequestParam()`: raw wire JSON.
        let removal: JSONValue = .object(["type": .string("tool_removal"), "tool": .object(["type": .string("tool_reference"), "name": .string("echo")])])
        let assistant = BetaMessageParam(role: .assistant, content: [
            .compaction(BetaCompactionBlockParam(content: "s", signature: "x", toolChanges: [.raw(removal)])),
        ])
        let (called, _) = try await runEchoTurn(messages: [assistant, .user("Hi")])
        XCTAssertFalse(called)

        let readdition: JSONValue = .object(["type": .string("tool_addition"), "tool": .object([
            "type": .string("tool_definition"), "definition": .object(["name": .string("echo"), "input_schema": .object([:])]),
        ])])
        let both = BetaMessageParam(role: .assistant, content: [
            .compaction(BetaCompactionBlockParam(content: "s", signature: "x", toolChanges: [.raw(removal), .raw(readdition)])),
        ])
        let (calledAgain, _) = try await runEchoTurn(messages: [both, .user("Hi")])
        XCTAssertTrue(calledAgain, "a raw definition addition after a removal restores the tool")
    }

    func testUnrecognizedRawToolChangesAreIgnoredForForwardCompatibility() async throws {
        let assistant = BetaMessageParam(role: .assistant, content: [
            .compaction(BetaCompactionBlockParam(content: "s", signature: "x", toolChanges: [
                .raw(.object(["type": .string("tool_banana"), "tool": .object(["type": .string("mystery"), "name": .string("echo")])])),
                .raw(.string("not even an object")),
            ])),
        ])
        let (called, _) = try await runEchoTurn(messages: [assistant, .user("Hi")])
        XCTAssertTrue(called, "nothing recognizable changed, so echo stays available")
    }

    func testAToolChangesBlockOutsideAnAssistantMessageIsNotFolded() async throws {
        let user = BetaMessageParam(role: .user, content: [
            .compaction(BetaCompactionBlockParam(content: "s", signature: "x", toolChanges: [
                .removal(BetaRequestToolRemovalBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo")))),
            ])),
        ])
        let (called, _) = try await runEchoTurn(messages: [user, .user("Hi")])
        XCTAssertTrue(called)
    }
}
