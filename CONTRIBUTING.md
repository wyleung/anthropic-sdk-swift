# Contributing

This SDK is hand-ported from the official [Python](https://github.com/anthropics/anthropic-sdk-python) and [TypeScript](https://github.com/anthropics/anthropic-sdk-typescript) SDKs, not generated from the OpenAPI spec. Porting a type or endpoint follows the same workflow every time:

1. Find the type or endpoint in the Python (`src/anthropic/types/...`, `src/anthropic/resources/...`) or TypeScript (`src/resources/...`) source. Prefer whichever reads more clearly for the case at hand — they're generated from the same spec and should agree.
2. Port it field-for-field into an idiomatic Swift `Codable` type or client method. Match wire field names via `JSONEncoder`/`JSONDecoder`'s snake_case conversion rather than hand-writing `CodingKeys` unless a name doesn't round-trip cleanly.
3. If it's a discriminated union (a `type`-tagged variant), model it as a Swift `enum` with associated values and a custom `Codable` conformance that switches on the discriminator — and add an `.unknown(type:, raw:)` case. Unlike the generated SDKs, this port will lag behind API releases, so every closed union must degrade gracefully on an unrecognized `type` instead of failing to decode.
4. Write a decode test using a literal JSON fixture (copy a real example response where possible) rather than round-tripping through your own encoder.

## Keeping up with the reference SDKs

[REFERENCE.md](REFERENCE.md) pins the exact Python/TypeScript commits this port has last been synced against, and has the commands to diff forward from that pin to find what's changed since. Check it periodically, port whatever's relevant, and update the pin.

## Scope

See the maintainer's roadmap for the current phase and what's intentionally deferred. Bedrock/Vertex/Foundry platform clients are out of scope — this project targets the direct Anthropic API on Apple platforms only.

## Running tests

```
swift build
swift test
```

CI runs `swift test --enable-code-coverage`; run that before you push, since the instrumentation slows execution and
can expose races a plain `swift test` hides.

### Tests against the real API

`LiveAPITests` and `BetaLiveAPITests` check what mocks cannot: that the server accepts what this SDK sends. They
**skip by default** and spend tokens when enabled, so they need both switches:

```
ANTHROPIC_LIVE_TESTS=1 ANTHROPIC_API_KEY=sk-ant-... swift test --filter LiveAPITests
```

`ANTHROPIC_LIVE_MODEL` overrides the model (default `claude-haiku-5-5`) and `ANTHROPIC_BASE_URL` the endpoint. With
`ANTHROPIC_LIVE_TESTS=1` but no key, only the invalid-key check runs; it sends a made-up key and spends nothing. The
Beta tests for inline tools, compaction and system-message fields skip, with the server's message, when an account
doesn't have that beta.

