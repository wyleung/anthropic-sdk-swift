import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Beta smoke tests against the real API. Skipped unless you opt in (they spend tokens):
///
///     ANTHROPIC_LIVE_TESTS=1 ANTHROPIC_API_KEY=sk-ant-... swift test --filter BetaLiveAPITests
///
/// The tests for features behind a beta flag your account may not have (inline tools, compaction, system-message
/// fields) skip with the server's own message when it says the flag or feature is unavailable, rather than fail.
final class BetaLiveAPITests: XCTestCase {
    private var client: AnthropicClient?

    private func liveClient() throws -> AnthropicClient {
        let apiKey = try Self.requireKey()
        let baseURL = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"].flatMap { $0.isEmpty ? nil : URL(string: $0) }
        let client = AnthropicClient(apiKey: apiKey, baseURL: baseURL ?? AnthropicClient.defaultBaseURL, timeout: 90)
        self.client = client
        return client
    }

    private static var model: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_LIVE_MODEL"].flatMap { $0.isEmpty ? nil : $0 } ?? "claude-haiku-5-5"
    }

    /// Skips unless live tests are switched on and a key is set. (Never call this inside `XCTUnwrap`, which
    /// records a thrown skip as a failure.)
    private static func requireKey() throws -> String {
        let environment = ProcessInfo.processInfo.environment
        guard environment["ANTHROPIC_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Live API tests are off. Set ANTHROPIC_LIVE_TESTS=1 (and ANTHROPIC_API_KEY) to run them.")
        }
        guard let key = environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
            throw XCTSkip("ANTHROPIC_LIVE_TESTS=1 is set but ANTHROPIC_API_KEY is not.")
        }
        return key
    }

    /// Runs `body`; a 400, 403 or 404 means the account or model doesn't have this beta, so skip and say why.
    private func skippingIfUnavailable<T>(_ what: String, _ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as AnthropicError {
            switch error {
            case .badRequest(let detail), .permissionDenied(let detail), .notFound(let detail):
                throw XCTSkip("\(what) is not available to this account/model: \(detail.message)")
            default:
                throw error
            }
        }
    }

    private func text(of message: BetaMessage) -> String {
        message.content.compactMap { block -> String? in
            if case .text(let text) = block { return text.text }
            return nil
        }.joined()
    }

    func testBetaCreateAndCountTokens() async throws {
        let client = try liveClient()
        let messages = [BetaMessageParam.user("Reply with the single word: ok")]

        let reply = try await client.beta.messages.create(
            BetaMessageCreateParams(model: Self.model, maxTokens: 16, messages: messages)
        )
        let count = try await client.beta.messages.countTokens(
            BetaMessageCountTokensParams(model: Self.model, messages: messages)
        )

        XCTAssertFalse(text(of: reply).isEmpty)
        XCTAssertGreaterThan(count.inputTokens, 0)
    }

    /// Streams each reply and starts the tool as soon as the model has moved on from its call.
    func testBetaToolRunnerWithEagerExecution() async throws {
        let client = try liveClient()
        let calls = LiveCounter()
        let runner = BetaToolRunner(
            client: client,
            params: BetaMessageCreateParams(
                model: Self.model, maxTokens: 256,
                messages: [.user("Call the add tool with a=2417 and b=5183, then tell me the result.")]
            ),
            tools: [AnyAnthropicTool(LiveAddTool(onCall: { calls.increment() }))],
            maxIterations: 5,
            runToolsEagerly: true
        )

        let final = try await runner.run()

        XCTAssertEqual(calls.count, 1, "the tool should run exactly once, however early it started")
        XCTAssertTrue(text(of: final).contains("7600") || text(of: final).contains("7,600"), text(of: final))
    }

    /// The model is told about the `add` tool only mid-run, by a `tool_addition` block.
    func testAToolAddedMidRunIsOfferedToAndCalledByTheModel() async throws {
        let client = try liveClient()
        let calls = LiveCounter()
        let box = BetaRunnerBox()
        let starter = AnyAnthropicTool(BetaStarterTool { box.runner?.addTools([AnyAnthropicTool(LiveAddTool(onCall: { calls.increment() }))]) })
        let runner = BetaToolRunner(
            client: client,
            params: BetaMessageCreateParams(
                model: Self.model, maxTokens: 512,
                messages: [.user("First call the starter tool. After it, call the add tool with a=2417 and b=5183 and tell me the result.")]
            ),
            tools: [starter],
            betas: ["inline-tools-2026-09-15"],
            maxIterations: 6
        )
        box.runner = runner

        let final = try await skippingIfUnavailable("Inline tools (inline-tools-2026-09-15)") { try await runner.run() }

        XCTAssertGreaterThanOrEqual(calls.count, 1, "the model never called the tool that was added mid-run")
        XCTAssertTrue(text(of: final).contains("7600") || text(of: final).contains("7,600"), text(of: final))
    }

    func testCompactionAfterTheFinalTurnProducesACompactionBlock() async throws {
        let client = try liveClient()
        let runner = BetaToolRunner(
            client: client,
            params: BetaMessageCreateParams(
                model: Self.model, maxTokens: 64,
                messages: [.user("Tell me one fact about octopuses, in a sentence.")]
            ),
            tools: [],
            betas: ["compact-2026-09-04"]
        )
        let compacted = LiveCounter()
        runner.onCompaction = { _ in compacted.increment() }
        try runner.compactBeforeNextTurn()

        _ = try await skippingIfUnavailable("Compaction (compact-2026-09-04)") { try await runner.run() }

        guard compacted.count > 0 else {
            throw XCTSkip("The API returned no summary for this short conversation, so nothing was compacted.")
        }
        guard case .compaction? = runner.messages.first?.content.first else {
            return XCTFail("the history was not replaced by the compaction block")
        }
        XCTAssertEqual(runner.messages.count, 1)
    }

    func testASystemMessageWithClearAtIsAccepted() async throws {
        let client = try liveClient()
        let messages = [
            BetaMessageParam(
                role: .system, content: [.standard(.text(TextBlockParam(text: "Answer in exactly one word.")))],
                clearAt: .nextUserMessage
            ),
            .user("What is the capital of France?"),
        ]

        let reply = try await skippingIfUnavailable("System-message clear_at (mid-conversation-system-clear-at-2026-08-21)") {
            try await client.beta.messages.create(
                BetaMessageCreateParams(model: Self.model, maxTokens: 16, messages: messages),
                betas: ["mid-conversation-system-clear-at-2026-08-21"]
            )
        }

        XCTAssertFalse(text(of: reply).isEmpty)
    }
}

private final class BetaRunnerBox: @unchecked Sendable {
    var runner: BetaToolRunner?
}

/// A tool that does nothing but run a closure, so a test can change the runner from inside a tool call.
private struct BetaStarterTool: AnthropicTool {
    let name = "starter"
    let description: String? = "Call this first. It takes no input."
    let inputSchema: JSONValue = .object(["type": .string("object"), "properties": .object([:])])
    let onCall: @Sendable () -> Void

    init(onCall: @escaping @Sendable () -> Void) {
        self.onCall = onCall
    }

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput {
        onCall()
        return .text("The add tool is now available.")
    }
}

/// Adds two numbers, for the runner tests. (The GA and Beta test targets don't share code.)
private struct LiveAddTool: AnthropicTool {
    let name = "add"
    let description: String? = "Adds two numbers and returns the sum."
    let inputSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object(["a": .object(["type": .string("number")]), "b": .object(["type": .string("number")])]),
        "required": .array([.string("a"), .string("b")]),
    ])
    let onCall: @Sendable () -> Void

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput {
        onCall()
        guard case .number(let a)? = input["a"], case .number(let b)? = input["b"] else {
            throw ToolError("Expected numbers `a` and `b`.")
        }
        return .text(String(Int(a + b)))
    }
}

private final class LiveCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
