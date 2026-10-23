# Changelog

Versions follow the TypeScript SDK version this package is synced to (see "Versioning" in
[REFERENCE.md](REFERENCE.md)), so `1.1.0` is synced to TypeScript `1.1.0` (and Python `2.1.0`).

## 1.1.0, 2026-10-23

The first tagged release; API version `2026-10-21`. Until now the package was used by tracking `main`, and this is
a **breaking** change for anyone who did. It follows the reference SDKs' move to API version `2026-10-21`, and it fixes
several bugs in how credentials and headers were handled. Read "Upgrading" first.

### Upgrading

Most apps need no change. Check these, most likely first.

**1. Exhaustive `switch` statements need new cases.**

- `AnthropicError` has three new cases: `.invalidArgument(message:)`, `.credentials(message:)` and
  `.identityTokenFile(message:path:)`. Add them, or a `default`.
- `MessageStreamEvent` and `BetaMessageStreamEvent` have a new `.passthrough` case, carrying an event the SDK
  does not model or one that arrives before `message_start`. These used to be dropped or to fail the stream.

**2. Credential failures are no longer `.responseValidation`.** A missing profile, an unreadable or unsafe
credentials file, an invalid profile name, or an unset required variable used to be thrown as
`.responseValidation`, which means "the server sent something unusable". They are now `.credentials` or
`.identityTokenFile`. `AnthropicError.isCredentialsError` is true for both. A failed token *exchange* with the
server is unchanged.

**3. A client has one credential.** Passing more than one of `apiKey`, `authProvider` and `profile` used to be
settled silently (the provider won). It is now an error:

- `AnthropicClient.resolvingCredentials(...)` throws `.invalidArgument`.
- `AnthropicClient(apiKey:authProvider:...)` cannot throw, so the **first request** fails with `.invalidArgument`.

Drop the argument you did not mean to pass.

**4. Credential resolution order changed.** First match wins:

1. an explicit argument (`authProvider`, `apiKey` or `profile`);
2. `ANTHROPIC_API_KEY`, then `ANTHROPIC_AUTH_TOKEN`;
3. `ANTHROPIC_PROFILE`;
4. workload identity federation variables (`ANTHROPIC_FEDERATION_RULE_ID`, `ANTHROPIC_ORGANIZATION_ID`,
   `ANTHROPIC_IDENTITY_TOKEN` or `ANTHROPIC_IDENTITY_TOKEN_FILE`);
5. the active profile: the one `<config dir>/active_config` names, otherwise `default`.

`ANTHROPIC_CONFIG_DIR` only says where profiles live and **no longer selects one**. Before, setting it (or
writing `active_config`) beat workload identity variables; now they win. If you set the directory or wrote
`active_config` and the active profile is broken, resolution still fails rather than falling through. An empty
environment variable now counts as unset, including `ANTHROPIC_IDENTITY_TOKEN`, and in the plain
`AnthropicClient(...)` initializer.

**5. API keys are sent as `Authorization: Bearer <key>`** and `anthropic-version` is `2026-10-21`
(`AnthropicClient.defaultAnthropicVersion`). Nothing to do unless you read `APIKeyProvider.authHeader()`, which now
returns `("authorization", "Bearer ...")`, or assert on the old `x-api-key` header in tests. A custom
`CredentialProvider` that returns `x-api-key` keeps working.

**6. Tool runners stop in different places.** `ToolRunner` and `BetaToolRunner` now decide from the turn's
`stop_reason`, as the reference runners do:

- `tool_use` runs the turn's tools (unchanged).
- `pause_turn`, and Beta's `compaction`, send the unfinished turn back unchanged and continue. The runner used to
  stop there with the answer unfinished.
- every other stop reason (`end_turn`, `max_tokens`, `stop_sequence`, `model_context_window_exceeded`, `refusal`,
  or one this SDK does not know) stops **without running that turn's tool calls**. A `max_tokens` turn can end in a
  truncated call; the runner used to execute it.

**7. A server `Retry-After` is now honored when it is long.** A value over 60 seconds used to be ignored in favour
of short exponential backoff; it is now honored (capped near 49 days). A client that gets `Retry-After: 3600` will
sleep for an hour before retrying. If that is not what you want, lower `maxRetries` or set a request timeout.

**8. Credential and config files are checked more strictly.** A credentials file readable by group or others, or a
config file writable by them, is refused (`chmod 600` the credentials, `chmod 644` or tighter the config). Token
requests no longer follow redirects. Empty ids passed for a path parameter (`files.retrieve("")`) throw
`.invalidArgument` instead of silently addressing a different endpoint.

**9. Beta type changes.** Fix at the call site:

| Was | Now |
|---|---|
| `BetaMessage.diagnostics: JSONValue?` | `Diagnostics?` |
| `BetaMessageCreateParams.diagnostics: JSONValue?` | `DiagnosticsParam?` |
| `BetaMessageCreateParams.thinking: ThinkingConfigParam?` | `BetaThinkingConfigParam?` (adds `blockBinding`) |
| `BetaModelInfo.capabilities: ModelCapabilities?` | `BetaModelCapabilities?` (adds `compaction`) |
| `BetaSkill`, `BetaSkillSummary` | `BetaSkill` is now GA's `Skill`; `BetaSkillSummary` is removed. `displayTitle` is `displayName`, `latestVersion` is `latestVersionId`, `source` is a `SkillSource` |
| `BetaSkillVersion` (had `directory`, `version`) | GA's `SkillVersion`, which has neither |
| `BetaUserProfile.relationship`, `BetaUserProfileRelationship` | `accessType`, `BetaUserProfileAccessType` (also on create and update params) |
| `BetaManagedAgentsSessionAgent.multiagent: ...SessionMultiagentCoordinator?` | `BetaManagedAgentsSessionMultiagent?`, a union that adds `multiagent_20261001` |
| `BetaRequestToolAdditionBlockParam.tool: BetaToolChangeReferenceParam` | `BetaToolAdditionParam` (reference *or* full definition). The old initializer still exists |
| `BetaManagedAgentsSessionResourceParams.authorizationToken: String` | `String?` (a public repository needs none) |
| `BetaManagedAgentsMultiagentParams` (a struct with `agents`) | an enum; `init(agents:)` still builds the coordinator form |

Also removed, because upstream removed them: `allowedCallers` on the computer and browser toolsets. Beta Files and
Skills no longer send their dated beta flags (`files-api-2025-04-14`, `skills-2025-10-02`), which upstream also dropped.

### Fixed

These predate this update.

- **The OAuth beta flag was lost.** A credential provider's `anthropic-beta: oauth-2025-04-20` was overwritten by
  any Beta call's own `betas:`, so OAuth, profile and workload-identity credentials reached the server without it.
  Flags are now combined, without repeats.
- **Per-call headers could lose to the provider's.** Headers were merged case-sensitively, so a per-call
  `Authorization` could sit beside the provider's `authorization` and win or lose at random. They are now merged
  case-insensitively, and the winning header keeps its casing.
- **The session runner kept the client's `x-api-key`** when given an `environmentKey`: assigning `nil` through a
  `[String: String?]` removes the entry rather than marking the header unset.
- **A rejected token could be cached again.** A refresh already running when a 401 invalidated the cache could put
  the rejected token straight back, failing the retry too.
- **The session tool runner's idle timeout never fired** for a session that went idle on `retries_exhausted` or
  `budget_reached`. It now arms on every idle stop reason except `requires_action`.

### Added

- **Messages:** `messages.countTokens` and `beta.messages.countTokens` (these were never in the original port);
  `speed`, cache `diagnostics`, `between_tools` thinking, web fetch `url_sources`; model lifecycle, line and
  capability fields and a `lifecycle` list filter; `RequestOptions.workspaceId`.
- **`Message.asRequestParam()` and `BetaMessage.asRequestParam()`:** the response as an assistant message to append
  to `messages`. Every modeled block kind converts, including web search, web fetch, code execution and tool search
  results; GA's conversion used to handle only five kinds.
- **`ToolUnionParam(tool)` and `BetaToolUnionParam(tool)`:** a tool defined for the runner, declared in a request you
  send yourself (`create`, `stream`, `countTokens`).
- **`BetaToolRunner`:**
  - `addTools(_:)`, `addTools(definitions:)` and `removeTools(_:)` change the tools mid-run without touching the
    `tools` param, so the prompt cache is not missed. They need the `inline-tools-2026-09-15` beta.
  - `compactBeforeNextTurn(_:)`, `onCompaction` and `messages` compact the conversation. They need the
    `compact-2026-09-04` beta.
  - `runToolsEagerly` and `deferToolCall` stream each reply and start a tool as soon as the model has moved on from
    its call. Calls run concurrently with each other and with the rest of the reply.
- **Beta Messages:** signed compaction blocks, input transformations, typed cache diagnostics, `mcp_tool_listing`
  blocks, pinned MCP toolsets, and `clearAt` and `outputConfig` on a `system` `BetaMessageParam`.
- **Managed Agents:** the `auto` permission policy and per-call `evaluation`, `execution_identity`, the
  `multiagent_20261001` union (advisor, subagents, workflows), inline agents, workflow-run events, refusal stop
  reasons, repository errors, thread `statuses` filter.
- **User profiles:** a GA `client.userProfiles` resource (enforcement, programs, external details), Beta
  `delete` and `actionURLs`, enforcement webhook events and `AnthropicWebhooks.parseUnverified`.
- **Errors and streams:** `AnthropicError.isCredentialsError`; unrecognized session event names are surfaced as
  `.unknown` instead of being dropped.

### Not ported

Deliberately left out, with reasons, in [REFERENCE.md](REFERENCE.md): the Admin/Organization API, the Bedrock,
Vertex, Foundry, AWS and Google Cloud clients, OpenTelemetry tracing, the CLI, the computer/browser agent toolsets
and their typed tool-call overlays, async credential providers, and the one-shot log warnings about shadowed
credentials (this SDK has no logging layer).
