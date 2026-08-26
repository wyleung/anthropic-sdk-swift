# anthropic-sdk-swift

An **unofficial, community-maintained** Swift client for the [Anthropic API](https://docs.anthropic.com). Not published or endorsed by Anthropic.

Ported by hand from the official [Python](https://github.com/anthropics/anthropic-sdk-python) and [TypeScript](https://github.com/anthropics/anthropic-sdk-typescript) SDKs, which remain the source of truth for behavior and parity. Targets Apple platforms only (iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+) via `URLSession` — no Linux support is planned.

## Status

Early scaffold (Phase 0). Only a non-streaming `messages.create` call is implemented. See `CONTRIBUTING.md` for the porting workflow and the project's roadmap for what's next: streaming, the tool runner, remaining GA resources, the credential chain, and the full Beta/Managed Agents surface.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/<owner>/anthropic-sdk-swift.git", branch: "main")
```

Then depend on `Anthropic` (and `AnthropicBeta` once it has content):

```swift
.product(name: "Anthropic", package: "anthropic-sdk-swift")
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

## License

MIT — see `LICENSE`.
