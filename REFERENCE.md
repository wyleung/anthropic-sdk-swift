# Reference SDK versions

This SDK is hand-ported from the official Python and TypeScript SDKs (see [CONTRIBUTING.md](CONTRIBUTING.md)). Because it's hand-written rather than generated, there's no automated way to detect when the reference SDKs add or change something. This file pins the exact reference commits the port has been synced against, so drift can be found by diffing forward from a known point instead of re-reading the whole reference source from scratch.

## Current pin

| Reference SDK | Commit | Version | Synced |
|---|---|---|---|
| [anthropic-sdk-python](https://github.com/anthropics/anthropic-sdk-python) | `4474f31efa48588eff590f04419230791e22419f` | v1.0.0 | 2026-08-28 |
| [anthropic-sdk-typescript](https://github.com/anthropics/anthropic-sdk-typescript) | `bfa9197f0182084941052be9752c948638421601` | v0.120.0 | 2026-08-28 |

## Sync in progress

Re-synced against upstream on 2026-10-22; the pin above stays put until the whole diff is ported or triaged out. Target: Python `9313f13a5a643ceed10fafba6785eab8e04b6e6e` (v2.1.0), TypeScript `5badc765f17d373405f300ee8e69e7f490b1f172` (v1.1.0).

Decisions: adopt API version `2026-10-21` (a breaking upstream release: `anthropic-version` bump, API keys sent as `Authorization: Bearer`, one credential per client with new env precedence); keep Swift's single `MessageParam` + `Role` rather than upstream's per-role union (same JSON); the Admin/Organization API, Bedrock/Vertex/Foundry/AWS/Google Cloud clients, OpenTelemetry and the CLI stay out of scope.

Order of work, each milestone committed and pushed on its own:

1. **Hardening and client behaviour** — done: credential-file permission checks, long `Retry-After`, no redirects on token requests, empty path ids rejected, unknown and pre-`message_start` stream events passed through, session-runner idle watchdog.
2. **GA surface additions** — done: `speed`/`usage.speed`, cache `diagnostics`, `between_tools` thinking, web-fetch `url_sources`, `ModelInfo` lifecycle/line/schedule fields, capability additions, the `lifecycle` list filter, `RequestOptions.workspaceId`, and `allowed_callers` removed from the computer/browser toolsets. (`content_too_large` needed no change — the error code is a plain `String`.) Still open from this milestone: Beta's `diagnostics` is a raw `JSONValue` and should become the typed `Diagnostics` in milestone 3.

   **Pre-existing gap, now closed:** `messages.count_tokens` (GA and Beta) existed upstream at the pin and before it but had never been implemented in Swift. Ported as `messages.countTokens` and `beta.messages.countTokens`, wire-checked against both Python and TypeScript. Beta's `compaction` param is deliberately absent: upstream documents `count_tokens` as ignoring it, and its typed config lands with milestone 3 (add it to `BetaMessageCountTokensParams` then).
3. **Beta and Managed Agents** — done. Beta Messages: signed compaction (`signature`/`tool_changes` echoed verbatim, the `compaction` param, `compaction` model capability), input transformations, typed cache diagnostics, thinking binding controls and `between_tools` (Beta now has its own `BetaThinkingConfigParam`), `mcp_tool_listing` blocks, pinned MCP toolsets and by-definition `tool_addition`, Beta model lifecycle fields. Beta Files/Skills moved onto GA's shapes and dropped their dated beta-header pins. Managed Agents: `auto` permission policy and per-call `evaluation`, `execution_identity`, the `multiagent_20261001` union (advisor/subagents/workflows, with an explicit `.useDefault` null), inline agents, workflow-run events, refusal stop reason and repository errors, MA web-fetch `url_sources`, thread `statuses` filter, optional GitHub token. User Profiles: new GA `client.userProfiles` resource (enforcement, programs, external details), Beta updated (`relationship` -> `accessType`, `delete`, `actionURLs`), enforcement webhook events and `parseUnverified`. The session SSE translator no longer drops unrecognized event names.

   **Deliberately not ported, by net-diff check (changelogs list intermediate states; only the net diff counts):**
   - Tunnel `transport` and create-time `token`: added in Python `88718ff4` and removed again two days later in `aa49ba7f`; net change since the pin is docs-only.
   - The ~214 computer/browser typed tool-call types (`BetaComputerLeftClickToolUseBlock`, ...): typing overlays that narrow an ordinary `tool_use` block by `name`/`toolset_name`; they are not in `BetaContentBlock` or the stream union, so no wire shape changed.
   - Memory store `description`/`metadata`/`archived_at` becoming required: Swift keeps them optional (decode-safe superset).
   - `BetaFallbackBlockParam.from` becoming `Required`: arrived in a client refactor (Python 1.8.0) with no documented server requirement; left optional.
   - Vault MCP OAuth `expires_at`, event-type filters typed as enums: Swift already had the former; the latter are plain strings by the query-filter rule.
   - The whole Admin/Organization API (decided out of scope).
4. **API version `2026-10-21`** — in progress, committed in steps.
   - Done: the `anthropic-version` header, and API keys sent as `Authorization: Bearer` (`APIKeyProvider`). Along the way: the session runner's `environmentKey` never actually dropped a custom provider's `x-api-key` (assigning `nil` through a `[String: String?]` subscript removes the entry instead of marking the header unset); now `.some(nil)`, with a test.
   - Done: the credential chain. `ANTHROPIC_CONFIG_DIR` and the `active_config` pointer no longer count as explicit profile selection, so WIF env vars outrank them (only `ANTHROPIC_PROFILE` ranks above WIF; a broken profile still raises when the user configured the directory or pointer); an empty `ANTHROPIC_IDENTITY_TOKEN`/key/token variable counts as unset; `apiKey`/`authProvider`/`profile` are mutually exclusive (`resolvingCredentials` throws `.invalidArgument`; the non-throwing initializer reports it on the first request); `AnthropicError.credentials` and `.identityTokenFile(path:)` (+ `isCredentialsError`) replace the `.responseValidation` that credential-file failures used to be thrown as. `TokenCache` no longer caches an unforced refresh that overlapped `invalidate()` (upstream `_end_refresh`).
   - Found and fixed on the way, both predating this milestone: a credential provider's `anthropic-beta: oauth-2025-04-20` marker was overwritten by any Beta call's own `betas:` (upstream's `AccessTokenAuth` unions the flags), and request headers were layered in a case-sensitive dictionary, so a per-call `Authorization` could lose to the provider's. `RequestHeaders` now layers case-insensitively and merges beta flags.
   - Deliberately not ported: the one-shot "env key shadows env token / profile" log warnings (this SDK has no logging layer); an explicit `authToken:` argument (Swift never had one; `ANTHROPIC_AUTH_TOKEN` and `StaticTokenProvider` cover it); async credential providers, zero-expiry per-request tokens and `copy()` credential inheritance (Python/TS client mechanics with no Swift counterpart: `withOptions` keeps the client's credential).
   - To do: `Message`-to-param helper, and the tool-runner helper features -- `compact_before_next_turn`, immediate `add_tools`/`remove_tools` (inline tools, `inline-tools-2026-09-15`; the runner's availability fold already understands the wire side), `run_tools_eagerly`, accepting tool objects directly. Re-verify that the Beta shapes ported in milestone 3 still decode once the version header changes.

## Checking for drift

From a local clone of each reference repo. The clones' `origin` is a personal fork that doesn't track upstream, so **fetch `upstream` and diff against `upstream/main`** — diffing against a local `HEAD` silently reports no drift:

```sh
cd anthropic-sdk-python && git fetch upstream --tags \
  && git log --oneline 4474f31..upstream/main -- src/anthropic ':!src/anthropic/lib/bedrock' ':!src/anthropic/lib/vertex' ':!src/anthropic/lib/foundry' ':!src/anthropic/lib/aws' ':!src/anthropic/lib/google_cloud'
cd anthropic-sdk-typescript && git fetch upstream --tags \
  && git log --oneline bfa9197..upstream/main -- src
```

Scope the paths to the whole source tree, not just `types/` and `resources/`: client behaviour that matters here (the `anthropic-version` constant, retry/backoff, streaming, credentials, tool runners) lives in `_constants.py`/`_base_client.py`/`lib/` (Python) and `client.ts`/`core/`/`lib/`/`tools/` (TypeScript), none of which a resources-only filter sees. The changelog (`git diff <pin> upstream/main -- CHANGELOG.md`) is the fastest way to triage before reading individual commits.

Read through the resulting commits for anything relevant to this port: new endpoints, new/changed fields, new beta headers, renamed or removed types, new discriminated-union variants. Port whatever applies, following the workflow in [CONTRIBUTING.md](CONTRIBUTING.md), then update the pin table above to the new commit/version/date.

## Notes

- Prefer diffing whichever reference SDK's history reads more clearly for a given change — they're generated from the same OpenAPI spec and should agree in substance.
- Moving the pin with no corresponding Swift change is a legitimate outcome (e.g. the diff was docs-only, or exclusively about Bedrock/Vertex/Foundry, which is out of scope per `CONTRIBUTING.md`). Don't force a port just to justify moving the pin — but do still update the "Synced" date so the next check starts from an accurate point.
