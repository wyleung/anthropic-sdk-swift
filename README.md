# anthropic-sdk-swift

An **unofficial, community-maintained** Swift client for the [Anthropic API](https://docs.anthropic.com). Not published or endorsed by Anthropic.

Ported by hand from the official [Python](https://github.com/anthropics/anthropic-sdk-python) and [TypeScript](https://github.com/anthropics/anthropic-sdk-typescript) SDKs, which remain the source of truth for behavior and parity. Targets Apple platforms only (iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+) via `URLSession` — no Linux support is planned.

## Status

Feature-complete port of the GA API surface plus the full Beta/Managed Agents surface: Messages (including streaming and the tool runner), Models, Files, Batches, Completions, and the credential chain in `Anthropic`; Agents, Sessions (events, resources, threads, SSE streaming), Environments, Deployments, Vaults, Memory Stores, User Profiles, Webhooks, and Tunnels in `AnthropicBeta`. 524/524 tests passing. See `CONTRIBUTING.md` for the porting workflow and conventions, and `REFERENCE.md` for the exact reference-SDK commits this port is synced against.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/wyleung/anthropic-sdk-swift.git", branch: "main")
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

### Managed Agents (Beta)

```swift
import Anthropic
import AnthropicBeta

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

## License

MIT — see `LICENSE`.
