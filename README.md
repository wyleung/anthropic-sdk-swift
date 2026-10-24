# anthropic-sdk-swift

An **unofficial, community-maintained** Swift client for the [Anthropic API](https://docs.anthropic.com). Not published or endorsed by Anthropic.

Ported by hand from the official [Python](https://github.com/anthropics/anthropic-sdk-python) and [TypeScript](https://github.com/anthropics/anthropic-sdk-typescript) SDKs, which remain the source of truth for behavior and parity. It uses `URLSession`, so it targets Apple platforms only; no Linux support is planned.

## Status

A port of the GA API surface plus the Beta and Managed Agents surface:

- **`Anthropic`**: Messages (including streaming, token counting and the tool runner), Models, Files, Skills, Message Batches, User Profiles, and the credential chain.
- **`AnthropicBeta`**: Beta Messages (compaction, runtime tool changes), Agents, Sessions (events, resources, threads, SSE streaming), Environments, Deployments, Vaults, Memory Stores, User Profiles, Webhooks, and Tunnels.

The package declares iOS 15+, macOS 12+, watchOS 8+, tvOS 15+ and visionOS 1+. CI builds and tests on macOS only.

Out of scope: the Admin/Organization API, the Bedrock, Vertex, Foundry, AWS and Google Cloud clients, OpenTelemetry tracing, and the CLI.

See [CHANGELOG.md](CHANGELOG.md) for what changed in each release and how to upgrade, [CONTRIBUTING.md](CONTRIBUTING.md) for the porting workflow, and [REFERENCE.md](REFERENCE.md) for the exact reference-SDK commits this port is synced against.

The package version follows the TypeScript SDK version it is synced to: `1.1.0` is synced to TypeScript `1.1.0` (and Python `2.1.0`), so you can tell which reference release your copy corresponds to.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/wyleung/anthropic-sdk-swift.git", from: "1.1.0")
```

Then depend on `Anthropic` for the GA API, or `AnthropicBeta` for the beta/Managed Agents surface as well:

```swift
.product(name: "Anthropic", package: "anthropic-sdk-swift")
// and/or
.product(name: "AnthropicBeta", package: "anthropic-sdk-swift")
```

## Usage

```swift
import Anthropic

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
```

### Streaming

```swift
let stream = try await client.messages.stream(
    MessageCreateParams(model: "claude-opus-5", maxTokens: 1024, messages: [.user("Write a haiku.")])
)
for try await text in await stream.textStream {
    print(text, terminator: "")
}
let message = try await stream.finalMessage()
```

`stream.events` gives every event instead (`.text`, `.thinking`, `.inputJSON`, ...), and any number of readers can consume the same stream. An event the SDK doesn't model arrives as `.passthrough` rather than being dropped.

### Continuing a conversation

`asRequestParam()` turns a response into the assistant message to send back, with every block exactly as received (thinking signatures, tool-use ids and server-tool results included):

```swift
var messages: [MessageParam] = [.user("Name a prime number.")]
let reply = try await client.messages.create(
    MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: messages)
)
messages.append(try reply.asRequestParam()) // the assistant turn, exactly as received
messages.append(.user("And a bigger one?"))
```

### Tools

Describe a tool once, and `ToolRunner` runs the call, execute, repeat loop for you:

```swift
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

let runner = ToolRunner(
    client: client,
    params: MessageCreateParams(
        model: "claude-opus-5", maxTokens: 1024, messages: [.user("What's the weather in Paris?")]
    ),
    tools: [AnyAnthropicTool(GetWeather())],
    maxIterations: 10
)
let answer = try await runner.run()
```

- Tool calls in one turn run concurrently, and their results go back in the order the model made the calls.
- Throw `ToolError` to control exactly what the model is told. Any other error you throw is reported to the model as an error result, so the loop carries on.
- The runner runs tools only when the turn's `stop_reason` is `tool_use`. A turn that ends any other way (`max_tokens`, `end_turn`, `refusal`, ...) stops the loop without running its tool calls, and a `pause_turn` is sent back unchanged so the server can finish it.

To declare the same tool in a request you send yourself (`create`, `stream` or `countTokens`), use `ToolUnionParam(GetWeather())`:

```swift
MessageCreateParams(
    model: "claude-opus-5", maxTokens: 1024, messages: [.user("What's the weather in Paris?")],
    tools: [ToolUnionParam(GetWeather())]
)
```

### Errors and retries

Every failure is an `AnthropicError`:

```swift
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
}
```

HTTP failures carry an `APIErrorDetail` (status code, request id, message, body). `.credentials` and `.identityTokenFile` mean credentials could not be loaded, so the API request was never sent (`error.isCredentialsError` covers both), and `.invalidArgument` means the SDK refused to send something, such as an empty id in a path.

Connection errors, timeouts, `408`, `409`, `429` and `5xx` responses are retried, twice by default, with backoff. A server `Retry-After` is honored, even a long one (up to about 49 days), and `x-should-retry` overrides the default. Change the defaults on the client, or per client copy or call:

```swift
let client = AnthropicClient(apiKey: "sk-ant-...", maxRetries: 4, timeout: 120)
_ = try await client.withOptions(maxRetries: 0).messages.create(params)
_ = try await client.messages.create(params, options: RequestOptions(maxRetries: 1, timeout: 30))
```

## Authentication

A client has **one** credential. Passing more than one of `apiKey`, `authProvider` and `profile` is an error.

`AnthropicClient(apiKey:)` never touches disk and never throws. It uses the key you pass, else `ANTHROPIC_API_KEY`, else `ANTHROPIC_AUTH_TOKEN`. To also use profiles and workload identity federation, resolve credentials explicitly (this can read files and call the network, so it is `async throws`):

```swift
let fromEnvironment = try await AnthropicClient.resolvingCredentials()
let fromProfile = try await AnthropicClient.resolvingCredentials(profile: "work")
```

It picks the first match:

1. an explicit argument: `authProvider`, `apiKey` or `profile`;
2. `ANTHROPIC_API_KEY`, then `ANTHROPIC_AUTH_TOKEN`;
3. `ANTHROPIC_PROFILE`, the profile it names;
4. workload identity federation: `ANTHROPIC_FEDERATION_RULE_ID`, `ANTHROPIC_ORGANIZATION_ID`, and `ANTHROPIC_IDENTITY_TOKEN` or `ANTHROPIC_IDENTITY_TOKEN_FILE`;
5. the active profile: the one `active_config` names, otherwise `default`.

Profiles live in `~/.config/anthropic` (or `ANTHROPIC_CONFIG_DIR`, which only says where they are and does not select one). A credentials file that group or others can read, or a config file they can write, is refused. An empty environment variable counts as unset.

API keys are sent as `Authorization: Bearer`. To supply your own credential, for example a token you fetch yourself, conform to `CredentialProvider`:

```swift
struct MyProvider: CredentialProvider {
    func authHeader() async throws -> (name: String, value: String) {
        ("authorization", "Bearer \(try await currentToken())")
    }

    func invalidate() async {} // called once after a 401, before the request is retried
}

let client = AnthropicClient(authProvider: MyProvider())
```

Select a workspace for a request with `RequestOptions(workspaceId:)`:

```swift
_ = try await client.messages.create(params, options: RequestOptions(workspaceId: "wrkspc_..."))
```

## Beta

`AnthropicBeta` adds `client.beta`. Beta calls take the beta flags to send:

```swift
import AnthropicBeta

let message = try await client.beta.messages.create(
    BetaMessageCreateParams(model: "claude-opus-5", maxTokens: 1024, messages: [.user("Hello")]),
    betas: ["compact-2026-09-04"]
)
```

### Changing tools and compacting while a run is in flight

`BetaToolRunner` can change what the model may use without touching the `tools` parameter, which would invalidate the prompt cache, and can summarize a long conversation:

```swift
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
```

- `addTools` and `removeTools` need the `inline-tools-2026-09-15` beta and act at once; the model is told with the next request. `addTools(definitions:)` adds server tools by definition.
- `compactBeforeNextTurn` needs the `compact-2026-09-04` beta. It runs after the current turn, including its tool calls, and `onCompaction` is called with the summary. `run()` still returns the last turn.
- `runToolsEagerly` streams each reply and starts a tool as soon as the model has moved on from its call, so slow tools overlap with the rest of the reply. A started call is never run twice. This is optimistic: if the turn then ends without running tools, those calls will already have run. Use `deferToolCall` to hold back any call that must not run unless the turn goes on to run its tools.

`client.beta.sessions.events.toolRunner(sessionId:tools:)` does the same job for Managed Agents sessions.

### Managed Agents

```swift
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
```

### Webhooks

`AnthropicWebhooks.unwrap` verifies a webhook's signature and returns the event. It throws `.webhookValidation` for a missing header, a timestamp more than five minutes off, or a signature that doesn't match:

```swift
let event = try AnthropicWebhooks.unwrap(payload: body, headers: requestHeaders, key: signingKey)
```

## Tests

`swift test` runs the mocked suite, which needs no network. Smoke tests against the real API are in the repo but skip unless you opt in with `ANTHROPIC_LIVE_TESTS=1` and an API key, since they spend tokens; see [CONTRIBUTING.md](CONTRIBUTING.md). Every example above is compiled by the test suite (`ReadmeSnippetsTests`), so they stay in step with the API.

## License

MIT — see `LICENSE`.
