import XCTest
@testable import Anthropic
@testable import AnthropicBeta

private struct ClosureTool: AnthropicTool {
    let name: String
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

/// A flag one thread sets and another polls.
private final class Latch: @unchecked Sendable {
    private let lock = NSLock()
    private var _isSet = false
    private var _count = 0

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isSet
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func set() {
        lock.lock()
        _isSet = true
        _count += 1
        lock.unlock()
    }
}

/// Serves a scripted SSE reply to each request in turn, in pieces, and can pause between pieces until a
/// condition holds. That is what lets a test see what the runner did *while a reply was still arriving*,
/// which `MockURLProtocol`, delivering a body in one piece, cannot show.
private final class ScriptedStreamProtocol: URLProtocol {
    enum Step {
        case chunk(String)
        /// Blocks the delivery of the rest of the reply until `condition` holds, or `timeout` passes.
        case waitUntil(timeout: TimeInterval, condition: @Sendable () -> Bool)
        case run(@Sendable () -> Void)
    }

    private static let lock = NSLock()
    private static var scripts: [[Step]] = []
    private static var bodies: [[String: Any]] = []

    static func reset(scripts: [[Step]]) {
        lock.lock()
        self.scripts = scripts
        bodies = []
        lock.unlock()
    }

    static var requestBodies: [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return bodies
    }

    private static func next(for request: URLRequest) -> [Step] {
        lock.lock()
        defer { lock.unlock() }
        if let data = bodyData(from: request),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            bodies.append(object)
        }
        return scripts.isEmpty ? [] : scripts.removeFirst()
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScriptedStreamProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let script = Self.next(for: request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        DispatchQueue.global().async {
            for step in script {
                switch step {
                case .chunk(let text):
                    self.client?.urlProtocol(self, didLoad: Data(text.utf8))
                case .waitUntil(let timeout, let condition):
                    let deadline = Date().addingTimeInterval(timeout)
                    while !condition(), Date() < deadline { Thread.sleep(forTimeInterval: 0.005) }
                case .run(let action):
                    action()
                }
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
}

final class BetaToolRunnerEagerTests: XCTestCase {
    override func tearDown() {
        ScriptedStreamProtocol.reset(scripts: [])
        super.tearDown()
    }

    // MARK: - SSE building

    private static func event(_ type: String, _ json: String) -> String { "event: \(type)\ndata: \(json)\n\n" }

    private static let messageStart = event(
        "message_start",
        #"{"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":0}}}"#
    )

    /// A complete `tool_use` block, in the order the server sends one.
    private static func toolUseBlock(index: Int, id: String, name: String) -> String {
        event("content_block_start", #"{"type":"content_block_start","index":\#(index),"content_block":{"type":"tool_use","id":"\#(id)","name":"\#(name)","input":{}}}"#)
            + event("content_block_delta", #"{"type":"content_block_delta","index":\#(index),"delta":{"type":"input_json_delta","partial_json":"{}"}}"#)
            + event("content_block_stop", #"{"type":"content_block_stop","index":\#(index)}"#)
    }

    /// The text block that follows: its start is how the model shows it has moved on from the call before.
    private static func textBlock(index: Int) -> String {
        event("content_block_start", #"{"type":"content_block_start","index":\#(index),"content_block":{"type":"text","text":""}}"#)
            + event("content_block_delta", #"{"type":"content_block_delta","index":\#(index),"delta":{"type":"text_delta","text":"ok"}}"#)
            + event("content_block_stop", #"{"type":"content_block_stop","index":\#(index)}"#)
    }

    private static func ending(_ stopReason: String) -> String {
        event("message_delta", #"{"type":"message_delta","delta":{"stop_reason":"\#(stopReason)","stop_sequence":null},"usage":{"output_tokens":5}}"#)
            + event("message_stop", #"{"type":"message_stop"}"#)
    }

    private static let finalReply: [ScriptedStreamProtocol.Step] = [
        .chunk(
            messageStart.replacingOccurrences(of: "msg_1", with: "msg_final") + textBlock(index: 0) + ending("end_turn")
        ),
    ]

    private func makeRunner(
        tools: [AnyAnthropicTool],
        deferToolCall: (@Sendable (ToolUseBlock) -> Bool)? = nil
    ) -> BetaToolRunner {
        let client = AnthropicClient(apiKey: "test-key", urlSession: ScriptedStreamProtocol.makeSession())
        return BetaToolRunner(
            client: client,
            params: BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")]),
            tools: tools,
            runToolsEagerly: true,
            deferToolCall: deferToolCall
        )
    }

    private func toolResults(inRequest index: Int) throws -> [[String: Any]] {
        let bodies = ScriptedStreamProtocol.requestBodies
        let body = try XCTUnwrap(bodies.indices.contains(index) ? bodies[index] : nil, "request \(index + 1) was never made")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        return (messages.last?["content"] as? [[String: Any]]) ?? []
    }

    // MARK: - Running ahead of the reply

    /// The point of the feature: the call is running while the reply is still arriving, not after it.
    func testAToolStartsWhileTheReplyIsStillStreamingAndIsNotRunAgain() async throws {
        let started = Latch()
        let ranBeforeTheReplyEnded = Latch()
        let echo = AnyAnthropicTool(ClosureTool(name: "echo") { _, _ in
            started.set()
            return .text("echoed")
        })
        ScriptedStreamProtocol.reset(scripts: [
            [
                // The call, and the start of the block after it -- the model has moved on.
                .chunk(Self.messageStart + Self.toolUseBlock(index: 0, id: "toolu_1", name: "echo")
                    + Self.event("content_block_start", #"{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#)),
                .waitUntil(timeout: 10) { started.isSet },
                .run { if started.isSet { ranBeforeTheReplyEnded.set() } },
                // The rest of the reply only arrives now.
                .chunk(
                    Self.event("content_block_stop", #"{"type":"content_block_stop","index":1}"#) + Self.ending("tool_use")
                ),
            ],
            Self.finalReply,
        ])

        let final = try await makeRunner(tools: [echo]).run()

        XCTAssertTrue(ranBeforeTheReplyEnded.isSet, "the tool should have started before the rest of the reply was delivered")
        XCTAssertEqual(started.count, 1, "an eagerly started call must not be run a second time")
        XCTAssertEqual(final.id, "msg_final")
        let results = try toolResults(inRequest: 1)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?["tool_use_id"] as? String, "toolu_1")
        XCTAssertEqual(results.first?["content"] as? String, "echoed")
    }

    func testResultsKeepTheModelsOrderWhetherOrNotACallRanAhead() async throws {
        let slowFinished = Latch()
        let slow = AnyAnthropicTool(ClosureTool(name: "slow") { _, _ in
            try await Task.sleep(nanoseconds: 80_000_000)
            slowFinished.set()
            return .text("slow done")
        })
        let last = AnyAnthropicTool(ClosureTool(name: "last") { _, _ in .text("last done") })
        // `last` is the final block: nothing follows it but the end of the turn, so it runs with the rest.
        ScriptedStreamProtocol.reset(scripts: [
            [.chunk(
                Self.messageStart + Self.toolUseBlock(index: 0, id: "toolu_1", name: "slow")
                    + Self.toolUseBlock(index: 1, id: "toolu_2", name: "last") + Self.ending("tool_use")
            )],
            Self.finalReply,
        ])

        _ = try await makeRunner(tools: [slow, last]).run()

        XCTAssertTrue(slowFinished.isSet)
        let results = try toolResults(inRequest: 1)
        XCTAssertEqual(results.map { $0["tool_use_id"] as? String }, ["toolu_1", "toolu_2"])
        XCTAssertEqual(results.map { $0["content"] as? String }, ["slow done", "last done"])
    }

    /// Eager running is optimistic: a turn cut off by `max_tokens` runs no tools, but a call already started
    /// has begun, so it is finished rather than abandoned, and `run()` returns only once it has.
    func testACallStartedInTurnThatRunsNoToolsIsStillSettledBeforeRunReturns() async throws {
        let finished = Latch()
        let slow = AnyAnthropicTool(ClosureTool(name: "slow") { _, _ in
            try await Task.sleep(nanoseconds: 120_000_000)
            finished.set()
            return .text("done")
        })
        ScriptedStreamProtocol.reset(scripts: [
            [.chunk(Self.messageStart + Self.toolUseBlock(index: 0, id: "toolu_1", name: "slow") + Self.textBlock(index: 1) + Self.ending("max_tokens"))],
        ])

        let final = try await makeRunner(tools: [slow]).run()

        XCTAssertEqual(final.stopReason, .maxTokens)
        XCTAssertEqual(ScriptedStreamProtocol.requestBodies.count, 1, "a max_tokens turn ends the run")
        XCTAssertTrue(finished.isSet, "run() returned while a started tool was still running")
    }

    func testADeferredCallWaitsForTheTurnToRunItsTools() async throws {
        let safeStarted = Latch()
        let riskyStarted = Latch()
        let riskyStartedAheadOfTheReply = Latch()
        let safe = AnyAnthropicTool(ClosureTool(name: "safe") { _, _ in
            safeStarted.set()
            return .text("safe done")
        })
        let risky = AnyAnthropicTool(ClosureTool(name: "risky") { _, _ in
            riskyStarted.set()
            return .text("risky done")
        })
        ScriptedStreamProtocol.reset(scripts: [
            [
                .chunk(Self.messageStart + Self.toolUseBlock(index: 0, id: "toolu_1", name: "safe")
                    + Self.toolUseBlock(index: 1, id: "toolu_2", name: "risky") + Self.textBlock(index: 2)),
                .waitUntil(timeout: 10) { safeStarted.isSet },
                // Give a wrongly eager `risky` the same chance to show itself.
                .waitUntil(timeout: 0.3) { riskyStarted.isSet },
                .run { if riskyStarted.isSet { riskyStartedAheadOfTheReply.set() } },
                .chunk(Self.ending("tool_use")),
            ],
            Self.finalReply,
        ])

        _ = try await makeRunner(tools: [safe, risky], deferToolCall: { $0.name == "risky" }).run()

        XCTAssertTrue(safeStarted.isSet)
        XCTAssertFalse(riskyStartedAheadOfTheReply.isSet, "a deferred call must wait for the end of the reply")
        XCTAssertEqual(riskyStarted.count, 1, "but it still runs, once, with the turn's tools")
        XCTAssertEqual(try toolResults(inRequest: 1).map { $0["content"] as? String }, ["safe done", "risky done"])
    }

    func testACallToAnUnregisteredToolGetsItsErrorResultWithTheTurnNotAheadOfIt() async throws {
        ScriptedStreamProtocol.reset(scripts: [
            [.chunk(Self.messageStart + Self.toolUseBlock(index: 0, id: "toolu_1", name: "ghost") + Self.textBlock(index: 1) + Self.ending("tool_use"))],
            Self.finalReply,
        ])

        _ = try await makeRunner(tools: []).run()

        let result = try XCTUnwrap(try toolResults(inRequest: 1).first)
        XCTAssertEqual(result["is_error"] as? Bool, true)
        XCTAssertEqual(result["content"] as? String, "Error: Tool 'ghost' not found")
    }

    // MARK: - The tracker

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try HTTPTransport.decoder.decode(type, from: Data(json.utf8))
    }

    private func stop(_ index: Int, toolUse id: String) throws -> BetaMessageStreamEvent {
        let block = try decode(BetaContentBlock.self, #"{"type":"tool_use","id":"\#(id)","name":"echo","input":{}}"#)
        return .contentBlockStop(BetaContentBlockStopEvent(index: index, contentBlock: block))
    }

    private func start(_ index: Int, _ blockJSON: String) throws -> BetaMessageStreamEvent {
        .contentBlockStart(try decode(
            BetaRawContentBlockStartEvent.self, #"{"type":"content_block_start","index":\#(index),"content_block":\#(blockJSON)}"#
        ))
    }

    private func delta(_ stopReason: String) throws -> BetaMessageStreamEvent {
        .messageDelta(try decode(
            BetaRawMessageDeltaEvent.self,
            #"{"type":"message_delta","delta":{"stop_reason":"\#(stopReason)","stop_sequence":null},"usage":{"output_tokens":1}}"#
        ))
    }

    func testTheModelHasMovedOnWhenTheNextBlockStarts() throws {
        var tracker = BetaEagerCallTracker()
        XCTAssertNil(tracker.track(try start(0, #"{"type":"tool_use","id":"toolu_1","name":"echo","input":{}}"#)))
        XCTAssertNil(tracker.track(try stop(0, toolUse: "toolu_1")), "its own stop is not enough")
        XCTAssertEqual(tracker.track(try start(1, #"{"type":"text","text":""}"#))?.id, "toolu_1")
        XCTAssertNil(tracker.track(try start(2, #"{"type":"text","text":""}"#)), "a call is handed over once")
    }

    func testTheTurnEndingInToolUseShowsTheLastCallWasFinishedOnPurpose() throws {
        var tracker = BetaEagerCallTracker()
        XCTAssertNil(tracker.track(try stop(0, toolUse: "toolu_1")))
        XCTAssertEqual(tracker.track(try delta("tool_use"))?.id, "toolu_1")
    }

    func testAReplyCutOffAtMaxTokensDoesNotCountAsMovedOn() throws {
        var tracker = BetaEagerCallTracker()
        XCTAssertNil(tracker.track(try stop(0, toolUse: "toolu_1")))
        XCTAssertNil(tracker.track(try delta("max_tokens")), "it closed the call with whatever input had arrived")
    }

    func testNothingStartsAfterAFallbackBlock() throws {
        var tracker = BetaEagerCallTracker()
        XCTAssertNil(tracker.track(try stop(0, toolUse: "toolu_1")))
        let fallback = #"{"type":"fallback","to":{"model":"claude-opus-5"},"from":{"model":"claude-sonnet-5"},"trigger":{"type":"refusal","category":"cyber"}}"#
        XCTAssertNil(tracker.track(try start(1, fallback)), "the refusal may have cut the call before it short")
        XCTAssertNil(tracker.track(try start(2, #"{"type":"text","text":""}"#)))
        XCTAssertNil(tracker.track(try stop(3, toolUse: "toolu_2")), "calls after the fallback wait for the reply to end")
        XCTAssertNil(tracker.track(try delta("tool_use")))
    }
}
