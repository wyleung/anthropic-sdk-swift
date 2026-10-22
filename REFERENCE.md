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

   **Pre-existing gap, not drift:** `messages.count_tokens` (GA and Beta) exists upstream at the pin and before it, but has never been implemented in Swift. Upstream's new `speed` param on it has nothing to attach to until it is.
3. Beta and Managed Agents: User Profiles GA and enforcement, agent `execution_identity`/workflows/auto-mode permissions, session repository errors and event-type filter, tunnel `transport` and create-time token, compaction, inline tool definitions and MCP tool-list pinning, new webhook events.
4. API version `2026-10-21`: header bump, Bearer API-key auth, new credential precedence (`CredentialsError`/`IdentityTokenFileError` equivalents), `Message`-to-param helper, tool-runner helper features.

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
