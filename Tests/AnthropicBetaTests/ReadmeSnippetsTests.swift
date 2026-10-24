import XCTest
import Anthropic
import AnthropicBeta

/// The code in README.md, compiled against the **public** API only (no `@testable`), so an example that stops
/// compiling, or that quietly relied on an internal symbol, fails here instead of in a reader's project.
///
/// Nothing in `ReadmeSnippets` is called: it would need a network and a key. Keep each function in step with
/// the README section it names.
enum ReadmeSnippets {
    // MARK: Usage

    static func messages() async throws {
        let client = AnthropicClient(apiKey: "sk-ant-...") // or set ANTHROPIC_API_KEY

        let message = try await client.messages.create(
            MessageCreateParams(
                model: "claude-opus-5",
                maxTokens: 1024,
                messages: [.user("Hello, Claude")]
            )
        )

        if case .text(let block) = message.content.first {
            print(block.text)
        }
    }

    static func streaming(client: AnthropicClient) async throws {
        let stream = try await client.messages.stream(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 1024, messages: [.user("Write a haiku.")])
        )
        for try await text in await stream.textStream {
            print(text, terminator: "")
        }
        let message = try await stream.finalMessage()
        print(message.usage.outputTokens)
    }

    static func conversation(client: AnthropicClient) async throws {
        var messages: [MessageParam] = [.user("Name a prime number.")]
        let reply = try await client.messages.create(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: messages)
        )
        messages.append(try reply.asRequestParam()) // the assistant turn, exactly as received
        messages.append(.user("And a bigger one?"))
    }

    // MARK: Tools

    struct GetWeather: AnthropicTool {
        let name = "get_weather"
        let description: String? = "Current weather for a city."
        let inputSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object(["city": .object(["type": .string("string")])]),
            "required": .array([.string("city")]),
        ])

        func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput {
            guard let city = input["city"]?.stringValue else { throw ToolError("`city` is required.") }
            return .text("Sunny, 21°C in \(city)")
        }
    }

    static func toolRunner(client: AnthropicClient) async throws {
        let runner = ToolRunner(
            client: client,
            params: MessageCreateParams(
                model: "claude-opus-5", maxTokens: 1024, messages: [.user("What's the weather in Paris?")]
            ),
            tools: [AnyAnthropicTool(GetWeather())],
            maxIterations: 10
        )
        let answer = try await runner.run()
        print(answer.content)
    }

    static func declareToolYourself() -> MessageCreateParams {
        MessageCreateParams(
            model: "claude-opus-5", maxTokens: 1024, messages: [.user("What's the weather in Paris?")],
            tools: [ToolUnionParam(GetWeather())]
        )
    }

    // MARK: Errors and retries

    static func errors(client: AnthropicClient, params: MessageCreateParams) async {
        do {
            _ = try await client.messages.create(params)
        } catch let error as AnthropicError {
            switch error {
            case .rateLimited(let detail), .overloaded(let detail):
                print("busy, request \(detail.requestID ?? "unknown")")
            case .authentication:
                print("check your credentials")
            case .credentials(let message), .invalidArgument(let message):
                print(message)
            default:
                print(error)
            }
        } catch {
            print(error)
        }
    }

    static func retries(params: MessageCreateParams) async throws {
        let client = AnthropicClient(apiKey: "sk-ant-...", maxRetries: 4, timeout: 120)
        _ = try await client.withOptions(maxRetries: 0).messages.create(params)
        _ = try await client.messages.create(params, options: RequestOptions(maxRetries: 1, timeout: 30))
    }

    // MARK: Authentication

    static func authentication() async throws {
        let fromEnvironment = try await AnthropicClient.resolvingCredentials()
        let fromProfile = try await AnthropicClient.resolvingCredentials(profile: "work")
        print(fromEnvironment, fromProfile)
    }

    struct MyProvider: CredentialProvider {
        func authHeader() async throws -> (name: String, value: String) {
            ("authorization", "Bearer \(try await currentToken())")
        }

        func invalidate() async {} // called once after a 401, before the request is retried
    }

    static func currentToken() async throws -> String { "token" }

    static func customProviderAndWorkspace(params: MessageCreateParams) async throws {
        let client = AnthropicClient(authProvider: MyProvider())
        _ = try await client.messages.create(params, options: RequestOptions(workspaceId: "wrkspc_..."))
    }

    // MARK: Beta

    struct Translate: AnthropicTool {
        let name = "translate"
        let inputSchema: JSONValue = .object(["type": .string("object")])

        func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput { "Bonjour" }
    }

    static func betaMessages(client: AnthropicClient) async throws {
        let message = try await client.beta.messages.create(
            BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 1024, messages: [.user("Hello")]),
            betas: ["compact-2026-09-04"]
        )
        print(message.id)
    }

    static func betaToolRunner(client: AnthropicClient) async throws {
        let runner = BetaToolRunner(
            client: client,
            params: BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 1024, messages: [.user("Plan my trip.")]),
            tools: [AnyAnthropicTool(GetWeather())],
            betas: ["inline-tools-2026-09-15", "compact-2026-09-04"],
            runToolsEagerly: true
        )

        // From a hook or a tool body, while the run is in flight:
        runner.addTools([AnyAnthropicTool(Translate())]) // offered to the model with the next request
        runner.removeTools(["get_weather"])
        try runner.compactBeforeNextTurn() // summarize the conversation before the next turn

        let final = try await runner.run()
        let history = runner.messages // the compacted conversation, to carry on from
        print(final.id, history.count)
    }

    static func managedAgents() async throws {
        let client = AnthropicClient(apiKey: "sk-ant-...")

        let agent = try await client.beta.agents.create(
            BetaAgentCreateParams(model: "claude-opus-5", name: "Research Assistant")
        )

        let environment = try await client.beta.environments.create(
            BetaEnvironmentCreateParams(name: "Default")
        )

        let session = try await client.beta.sessions.create(
            BetaSessionCreateParams(agent: .id(agent.id), environmentId: environment.id)
        )
        print(session.id)
    }

    static func webhooks(body: String, requestHeaders: [String: String], signingKey: String) throws {
        let event = try AnthropicWebhooks.unwrap(payload: body, headers: requestHeaders, key: signingKey)
        print(event.type)
    }
}

final class ReadmeSnippetsTests: XCTestCase {
    /// Every line of Swift in the README must also appear in this file, where it is compiled. Without this the
    /// README could be edited into something that no longer compiles and nothing would notice.
    func testEveryLineOfSwiftInTheReadmeIsCompiledInThisFile() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let readme = try String(contentsOf: repositoryRoot.appendingPathComponent("README.md"), encoding: .utf8)
        let thisFile = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)

        func normalized(_ text: String) -> String {
            text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let compiled = normalized(thisFile)
        // Package manifest fragments and imports are not part of an example's body.
        let notCompiledHere = ["import ", ".package(", ".product(", "// and/or"]

        let blocks = try NSRegularExpression(pattern: "```swift\\n(.*?)```", options: [.dotMatchesLineSeparators])
        let matches = blocks.matches(in: readme, range: NSRange(readme.startIndex..., in: readme))
        XCTAssertGreaterThan(matches.count, 10, "found too few Swift blocks; has the README layout changed?")

        var drifted: [String] = []
        for match in matches {
            let block = String(readme[Range(match.range(at: 1), in: readme)!])
            for line in block.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !notCompiledHere.contains(where: trimmed.hasPrefix) else { continue }
                // Compare the code, not a trailing explanatory comment.
                let code = trimmed.hasPrefix("//") ? trimmed : (trimmed.components(separatedBy: " // ").first ?? trimmed)
                if !compiled.contains(normalized(code)) { drifted.append(trimmed) }
            }
        }
        XCTAssertEqual(drifted, [], "README lines that are not compiled in ReadmeSnippetsTests.swift")
    }

    /// The part of the README that needs no network: the tool declaration it shows is the one the runner sends.
    func testTheReadmesToolDeclaresItselfAsACustomTool() throws {
        let wire = try JSONSerialization.jsonObject(
            with: HTTPTransport.encoder.encode(ReadmeSnippets.declareToolYourself().tools?.first)
        ) as? [String: Any]

        XCTAssertEqual(wire?["name"] as? String, "get_weather")
        XCTAssertEqual(wire?["type"] as? String, "custom")
    }
}
