# Reference SDK versions

This SDK is hand-ported from the official Python and TypeScript SDKs (see [CONTRIBUTING.md](CONTRIBUTING.md)). Because it's hand-written rather than generated, there's no automated way to detect when the reference SDKs add or change something. This file pins the exact reference commits the port has been synced against, so drift can be found by diffing forward from a known point instead of re-reading the whole reference source from scratch.

## Current pin

| Reference SDK | Commit | Version | Synced |
|---|---|---|---|
| [anthropic-sdk-python](https://github.com/anthropics/anthropic-sdk-python) | `4474f31efa48588eff590f04419230791e22419f` | v1.0.0 | 2026-08-28 |
| [anthropic-sdk-typescript](https://github.com/anthropics/anthropic-sdk-typescript) | `bfa9197f0182084941052be9752c948638421601` | v0.120.0 | 2026-08-28 |

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
