import XCTest
@testable import Anthropic

/// Smoke tests against the real API. They are skipped unless you opt in, because they spend tokens:
///
///     ANTHROPIC_LIVE_TESTS=1 ANTHROPIC_API_KEY=sk-ant-... swift test --filter LiveAPITests
///
/// Mocks cannot say whether the server accepts what this SDK sends (the Bearer API key, the
/// `anthropic-version` header, the shape of a request), so these check exactly that. `ANTHROPIC_LIVE_MODEL`
/// overrides the model (default `claude-haiku-5-5`) and `ANTHROPIC_BASE_URL` the endpoint.
enum Live {
    static var environment: [String: String] { ProcessInfo.processInfo.environment }

    static var model: String { environment["ANTHROPIC_LIVE_MODEL"].flatMap { $0.isEmpty ? nil : $0 } ?? "claude-haiku-5-5" }

    /// Throws `XCTSkip` unless live tests are switched on. (Call it directly, never inside `XCTUnwrap`, which
    /// records a thrown skip as a failure.)
    static func requireOptIn() throws {
        guard environment["ANTHROPIC_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Live API tests are off. Set ANTHROPIC_LIVE_TESTS=1 (and ANTHROPIC_API_KEY) to run them.")
        }
    }

    /// The opt-in, plus the API key.
    static func requireKey() throws -> String {
        try requireOptIn()
        guard let key = environment["ANTHROPIC_API_KEY"], !key.isEmpty else {
            throw XCTSkip("ANTHROPIC_LIVE_TESTS=1 is set but ANTHROPIC_API_KEY is not.")
        }
        return key
    }

    static func makeClient(apiKey: String) -> AnthropicClient {
        let baseURL = environment["ANTHROPIC_BASE_URL"].flatMap { $0.isEmpty ? nil : URL(string: $0) }
        return AnthropicClient(apiKey: apiKey, baseURL: baseURL ?? AnthropicClient.defaultBaseURL, timeout: 90)
    }
}

/// `3 + 4`, with a real schema, for the runner tests.
struct LiveAddTool: AnthropicTool {
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

final class LiveCounter: @unchecked Sendable {
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

final class LiveAPITests: XCTestCase {
    private var client: AnthropicClient?

    private func liveClient() throws -> AnthropicClient {
        let client = Live.makeClient(apiKey: try Live.requireKey())
        self.client = client
        return client
    }

    private func text(of message: Message) -> String {
        message.content.compactMap { block -> String? in
            if case .text(let text) = block { return text.text }
            return nil
        }.joined()
    }

    /// Needs no real key, so it spends nothing. If the server did not recognize `Authorization: Bearer` with
    /// the new `anthropic-version`, this would come back as a 400 about headers instead of a 401.
    func testAnInvalidKeyIsRejectedAsAnAuthenticationError() async throws {
        try Live.requireOptIn()
        let client = Live.makeClient(apiKey: "sk-ant-api03-live-test-this-key-is-not-valid")
        self.client = client

        do {
            _ = try await client.models.list(limit: 1)
            XCTFail("an invalid key must not be accepted")
        } catch AnthropicError.authentication(let detail) {
            XCTAssertEqual(detail.statusCode, 401)
        } catch {
            XCTFail("expected a 401 .authentication error, got \(error)")
        }
    }

    func testModelsListAndRetrieve() async throws {
        let client = try liveClient()

        let page = try await client.models.list(limit: 5)
        let first = try XCTUnwrap(page.data.first, "the account lists no models")
        let retrieved = try await client.models.retrieve(first.id)

        XCTAssertEqual(retrieved.id, first.id)
    }

    func testCreateAndCountTokens() async throws {
        let client = try liveClient()
        let messages = [MessageParam.user("Reply with the single word: ok")]

        let reply = try await client.messages.create(MessageCreateParams(model: Live.model, maxTokens: 16, messages: messages))
        let count = try await client.messages.countTokens(MessageCountTokensParams(model: Live.model, messages: messages))

        XCTAssertFalse(text(of: reply).isEmpty)
        XCTAssertGreaterThan(reply.usage.outputTokens, 0)
        XCTAssertGreaterThan(count.inputTokens, 0)
    }

    func testStreamingYieldsTheSameTextAsTheFinalMessage() async throws {
        let client = try liveClient()
        let stream = try await client.messages.stream(
            MessageCreateParams(model: Live.model, maxTokens: 32, messages: [.user("Reply with the single word: ok")])
        )

        var streamed = ""
        for try await piece in await stream.textStream { streamed += piece }
        let final = try await stream.finalMessage()

        XCTAssertFalse(streamed.isEmpty)
        XCTAssertEqual(streamed, text(of: final))
    }

    /// The real server must accept an assistant turn rebuilt by `asRequestParam()`.
    func testAnAssistantTurnSentBackWithAsRequestParamIsAccepted() async throws {
        let client = try liveClient()
        let first = [MessageParam.user("Reply with the single word: ok")]
        let reply = try await client.messages.create(MessageCreateParams(model: Live.model, maxTokens: 16, messages: first))

        let again = try await client.messages.create(
            MessageCreateParams(
                model: Live.model, maxTokens: 16,
                messages: first + [try reply.asRequestParam(), .user("Say it once more.")]
            )
        )

        XCTAssertFalse(text(of: again).isEmpty)
    }

    func testToolRunnerRunsAToolAndReturnsTheAnswer() async throws {
        let client = try liveClient()
        let calls = LiveCounter()
        let runner = ToolRunner(
            client: client,
            params: MessageCreateParams(
                model: Live.model, maxTokens: 256,
                messages: [.user("Call the add tool with a=2417 and b=5183, then tell me the result.")]
            ),
            tools: [AnyAnthropicTool(LiveAddTool(onCall: { calls.increment() }))],
            maxIterations: 5
        )

        let final = try await runner.run()

        XCTAssertGreaterThanOrEqual(calls.count, 1, "the model never called the tool")
        XCTAssertTrue(text(of: final).contains("7600") || text(of: final).contains("7,600"), text(of: final))
    }
}
