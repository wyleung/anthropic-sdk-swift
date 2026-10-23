import Foundation
import Anthropic

/// Beta counterpart to GA's `ToolRunner`, hardcoded to Beta's richer types rather than generic over
/// both. Ported from `lib/tools/_beta_runner.py`'s `BetaToolRunner`, and shares its call ->
/// execute-tools -> loop cycle with GA:
///
/// - Call `beta.messages.create`, then decide what to do from the turn's `stop_reason`, exactly as
///   the reference runners do (``Step``):
///   - `tool_use`: execute every `tool_use` block concurrently (a `TaskGroup`, matching both the
///     Python and TS runners keeping this concurrent rather than sequential) and batch all
///     resulting `tool_result` blocks into one `{role: "user", ...}` message, in original
///     `tool_use` order, before looping. Stop if the turn has no `tool_use` blocks.
///   - `pause_turn` and `compaction`: the turn is unfinished (a server tool hit its iteration limit,
///     or compaction handed the turn back before the model answered). Send it back unchanged,
///     running no tools, so the server continues it.
///   - anything else -- `end_turn`, `max_tokens`, `stop_sequence`, `model_context_window_exceeded`,
///     `refusal`, or a value this SDK doesn't know -- stop **without executing any `tool_use` block**
///     from that turn. A `max_tokens` turn can end in a truncated tool call, and a refusal means the
///     model never confirmed the side effects; neither can be replayed coherently afterward.
///
/// Two behaviors have no GA equivalent, since they only exist in the Beta wire format:
///
/// - **Container propagation**: if a response carries a `container`, its id is copied into the next
///   request so later turns (e.g. code execution) reuse the same sandbox. Like the TypeScript
///   runner (and unlike Python's unconditional overwrite), this never clobbers a container id the
///   caller already pinned -- it only fills in a missing one.
/// - **Tool availability tracking**: a `tool_removal`/`tool_addition` system-message block can
///   withdraw or restore a locally-registered tool mid-conversation. `run()` folds every such block
///   already in the conversation (before the current turn's new messages are appended) over the
///   base registry to decide what's dispatchable *right now*; a `tool_use` block naming a tool
///   that's registered but not currently available is treated the same as one that's unregistered.
///
/// Three things can change while a run is in flight, each callable from a hook, another task, or a tool
/// body:
///
/// - ``addTools(_:)`` / ``addTools(definitions:)`` and ``removeTools(_:)`` change the tools the model
///   can use *without* touching the `tools` param, which would miss the prompt cache. The runner acts
///   on them at once and tells the model in `tool_addition` / `tool_removal` blocks it sends, in one
///   `system` message, before the next request. Requires the `inline-tools-2026-09-15` beta.
/// - ``compactBeforeNextTurn(_:)`` replaces the conversation with a summary: the next request becomes a
///   compaction request, and the signed `compaction` block that comes back replaces the history.
///   Requires the `compact-2026-09-04` beta.
///
/// Out of scope: Python's `@beta_tool` decorator/reflection-based schema derivation -- Swift has no
/// runtime reflection over function parameters, so (like GA's `ToolRunner`) callers always supply an
/// explicit `AnthropicTool`.
///
/// Not `Sendable` and not safe to `run()` concurrently from multiple tasks -- like GA's `ToolRunner`
/// and both reference SDKs' runner classes, one `BetaToolRunner` drives one linear conversation.
public final class BetaToolRunner {
    private let client: AnthropicClient
    private let registry: BetaToolRegistry
    private let betas: [String]
    private let userProfileId: String?
    private let options: RequestOptions
    private let maxIterations: Int?

    private var params: BetaMessageCreateParams
    private var lastMessage: BetaMessage?

    /// Runs immediately before every `beta.messages.create` call; lets a caller inspect or rewrite
    /// the request (e.g. trimming history) each turn. Mirrors `set_messages_params`/an equivalent hook.
    /// Not applied to a compaction request, whose params are fixed by the compaction.
    public var beforeRequest: ((BetaMessageCreateParams) -> BetaMessageCreateParams)?
    /// Runs after the assistant turn and tool executions are batched into their two messages, right
    /// before they're appended to the conversation. Mirrors `append_messages`.
    public var onAppendMessages: (([BetaMessageParam]) -> Void)?
    /// Runs on the batched `{role: "user", ...}` tool-result message before it's appended, letting a
    /// caller rewrite it (e.g. to add `cache_control`). Mirrors `generate_tool_call_response`.
    public var onToolCallResponse: ((BetaMessageParam) -> BetaMessageParam)?
    /// Runs when a compaction response has replaced the conversation (see ``compactBeforeNextTurn(_:)``),
    /// with that response (`stopReason == .compaction`). The reference runners yield it as an item of
    /// their iteration; ``run()`` still returns the last *turn* rather than the compaction.
    public var onCompaction: ((BetaMessage) -> Void)?

    /// The conversation the next request will send. Read it from a hook, or after ``run()`` returns --
    /// for instance to carry on from the compacted history. It is the loop's own state, so reading it
    /// from another task while a run is in flight is a race.
    public var messages: [BetaMessageParam] { params.messages }

    public init(
        client: AnthropicClient,
        params: BetaMessageCreateParams,
        tools: [AnyAnthropicTool],
        betas: [String] = [],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions(),
        maxIterations: Int? = nil
    ) {
        self.client = client
        self.registry = BetaToolRegistry(tools: tools)
        self.betas = betas
        self.userProfileId = userProfileId
        self.options = options
        self.maxIterations = maxIterations
        self.params = params.with(tools: (params.tools ?? []) + tools.map { .tool(.custom($0.toolParam)) })
    }

    // MARK: - Changing a run in flight

    /// Gives the model more function tools without changing the `tools` param. They run straight away,
    /// in place of any tool of the same name, even for a call already in the message being handled; the
    /// model is told in `tool_addition` blocks with the next request. Requires the
    /// `inline-tools-2026-09-15` beta.
    public func addTools(_ tools: [AnyAnthropicTool]) {
        registry.add(tools)
    }

    /// Gives the model more tools by definition -- for server tools such as web search. The runner never
    /// runs these, and stops running a function tool of the same name. Requires the
    /// `inline-tools-2026-09-15` beta.
    public func addTools(definitions: [BetaToolUnionParam]) {
        registry.add(definitions: definitions)
    }

    /// Takes tools away from the model without changing the `tools` param. They stop being run at once,
    /// and the model is told in `tool_removal` blocks with the next request. Requires the
    /// `inline-tools-2026-09-15` beta.
    public func removeTools(_ names: [String]) {
        registry.remove(names: names)
    }

    public func removeTools(_ tools: [AnyAnthropicTool]) {
        registry.remove(names: tools.map(\.name))
    }

    /// Compacts the conversation before the model's next turn.
    ///
    /// This only schedules the compaction. Once the current turn has finished, including any tool calls,
    /// the runner sends a compaction request and replaces the message history with the response the API
    /// returns (``onCompaction`` is called with it), then carries on. If the run ends first, the final
    /// turn is added to the history and compacted, so ``messages`` is the compacted conversation -- but
    /// not when that turn ended with tool calls whose results were never sent: the API cannot compact
    /// a conversation with an unanswered tool call, so the request is dropped. Calling this again before
    /// it runs replaces the pending request. Requires the `compact-2026-09-04` beta.
    ///
    /// - Throws: ``AnthropicError/invalidArgument(message:)`` when the request's `context_management`
    ///   already has a compaction edit; the API does not accept a compaction block together with one.
    public func compactBeforeNextTurn(_ compaction: BetaCompactionConfigParam = BetaCompactionConfigParam()) throws {
        try Self.requireNoCompactionEdit(in: params)
        registry.scheduleCompaction(compaction)
    }

    // MARK: - Running

    /// Runs the loop to completion -- until the model's turn needs no more tool calls, or
    /// `maxIterations` is reached -- and returns the final `BetaMessage`.
    public func run() async throws -> BetaMessage {
        if params.compaction != nil {
            throw AnthropicError.invalidArgument(
                message: "`compaction` cannot be set on a tool runner: every request in the loop would compact "
                    + "again. Call `compactBeforeNextTurn()` when the conversation should be compacted instead."
            )
        }
        var iterations = 0
        var lastStopReason: BetaStopReason?
        while maxIterations.map({ iterations < $0 }) ?? true {
            // A paused turn has to go back as the last message, so queued tool changes wait for the
            // request after it. They are not appended through `onAppendMessages`: that is for the turn's
            // own messages.
            if lastStopReason != .pauseTurn, let changes = registry.takePendingToolChangesMessage() {
                params = params.with(messages: params.messages + [changes])
            }
            // The API cannot compact a conversation that ends mid-turn, so a paused turn is resumed first.
            if Self.step(after: lastStopReason) != .resume, let compaction = registry.takePendingCompaction() {
                try await compact(compaction)
                continue
            }
            iterations += 1

            var requestParams = params
            if let beforeRequest {
                requestParams = beforeRequest(requestParams)
            }
            let message = try await client.beta.messages.create(
                requestParams, betas: betas, userProfileId: userProfileId, options: options
            )
            lastMessage = message
            lastStopReason = message.stopReason
            propagateContainer(from: message)

            let step = Self.step(after: message.stopReason)
            if step == .stop {
                try await compactAfterFinalTurn(message)
                break
            }
            let assistantMessage = try message.asRequestParam()
            if step == .resume {
                params = params.with(messages: params.messages + [assistantMessage])
                onAppendMessages?([assistantMessage])
                continue
            }

            let toolUseBlocks = message.content.compactMap { block -> ToolUseBlock? in
                if case .toolUse(let toolUse) = block { return toolUse }
                return nil
            }
            guard !toolUseBlocks.isEmpty else {
                try await compactAfterFinalTurn(message)
                break
            }

            let history = params.messages
            let registry = self.registry
            let toolResults = await Self.executeToolUseBlocks(toolUseBlocks) { name in
                registry.tool(named: name, history: history)
            }
            var toolResultMessage = BetaMessageParam(
                role: .user,
                content: toolResults.map { .standard(.toolResult($0)) }
            )
            if let onToolCallResponse {
                toolResultMessage = onToolCallResponse(toolResultMessage)
            }

            let appended = [assistantMessage, toolResultMessage]
            params = params.with(messages: params.messages + appended)
            onAppendMessages?(appended)
        }

        guard let lastMessage else {
            throw AnthropicError.responseValidation(
                message: "BetaToolRunner stopped without ever receiving a response from the server.",
                body: nil
            )
        }
        return lastMessage
    }

    // MARK: - Compaction

    private static func requireNoCompactionEdit(in params: BetaMessageCreateParams) throws {
        guard params.hasCompactionEdit else { return }
        throw AnthropicError.invalidArgument(
            message: "`compactBeforeNextTurn()` can't be used while `context_management` has a compaction edit, "
                + "because the API doesn't accept a compaction block together with one. Remove the edit first."
        )
    }

    /// Sends the compaction request and, if it produced a summary, replaces the conversation with it.
    /// Not counted as an iteration.
    private func compact(_ compaction: BetaCompactionConfigParam) async throws {
        try Self.requireNoCompactionEdit(in: params)
        let message = try await client.beta.messages.create(
            params.forCompactionRequest(compaction), betas: betas, userProfileId: userProfileId, options: options
        )
        // Summary or not, the request went out with any edit made before it. Without a summary there is
        // nothing to replace the conversation with, so it carries on as it was.
        guard message.content.contains(where: { block in
            if case .compaction(let compactionBlock) = block { return !(compactionBlock.content ?? "").isEmpty }
            return false
        }) else { return }
        // The summary stands in for the turns it replaced, so a tool they withdrew has to stay withdrawn.
        registry.dropWithdrawnTools(history: params.messages)
        // The response has to be sent back as it came, first, replacing the messages it summarizes.
        params = params.with(messages: [try message.asRequestParam()])
        onCompaction?(message)
    }

    /// A compaction scheduled when the run's last turn finished: that turn joins the history first, so the
    /// summary includes the answer.
    private func compactAfterFinalTurn(_ message: BetaMessage) async throws {
        guard let compaction = registry.takePendingCompaction() else { return }
        // A turn that was cut short can end with tool calls that are never run, and the API can't compact a
        // conversation whose last turn has an unanswered tool call.
        if message.content.contains(where: { if case .toolUse = $0 { return true } else { return false } }) {
            return
        }
        params = params.with(messages: params.messages + [try message.asRequestParam()])
        try await compact(compaction)
    }

    /// Fills in a response's container id on the next request, but only when nothing was pinned
    /// there already -- matching the TypeScript runner's non-clobbering behavior rather than
    /// Python's unconditional overwrite, so a container id a caller explicitly set up front always
    /// wins.
    private func propagateContainer(from message: BetaMessage) {
        guard let container = message.container else { return }
        switch params.container {
        case nil:
            params = params.with(container: .id(container.id))
        case .id:
            return
        case .container(let existing):
            guard existing.id == nil else { return }
            params = params.with(container: .container(ContainerParams(id: container.id, skills: existing.skills)))
        }
    }

    /// What the loop does with a finished turn.
    enum Step: Equatable {
        case runTools, resume, stop
    }

    /// Every stop reason maps to exactly one step. `nil` and values this SDK doesn't know yet end the
    /// loop like any other finished turn rather than throwing.
    static func step(after stopReason: BetaStopReason?) -> Step {
        switch stopReason {
        case .toolUse: return .runTools
        case .pauseTurn, .compaction: return .resume
        case .endTurn, .maxTokens, .stopSequence, .refusal, .modelContextWindowExceeded, .unknown, nil: return .stop
        }
    }

    private static func executeToolUseBlocks(
        _ blocks: [ToolUseBlock],
        resolve: @escaping @Sendable (String) -> AnyAnthropicTool?
    ) async -> [ToolResultBlockParam] {
        await withTaskGroup(of: (Int, ToolResultBlockParam).self) { group in
            for (index, block) in blocks.enumerated() {
                group.addTask { (index, await executeSingle(block, resolve: resolve)) }
            }
            var byIndex: [Int: ToolResultBlockParam] = [:]
            for await (index, result) in group {
                byIndex[index] = result
            }
            return blocks.indices.map { byIndex[$0]! }
        }
    }

    private static func executeSingle(
        _ block: ToolUseBlock,
        resolve: @Sendable (String) -> AnyAnthropicTool?
    ) async -> ToolResultBlockParam {
        guard let tool = resolve(block.name) else {
            return ToolResultBlockParam(
                toolUseId: block.id,
                content: .text("Error: Tool '\(block.name)' not found"),
                isError: true
            )
        }

        let context = ToolRunContext(toolUseId: block.id, toolName: block.name)
        do {
            let output = try await tool.run(block.input, context: context)
            return ToolResultBlockParam(toolUseId: block.id, content: output.asToolResultContent)
        } catch let toolError as ToolError {
            return ToolResultBlockParam(
                toolUseId: block.id,
                content: toolError.content.asToolResultContent,
                isError: true
            )
        } catch {
            return ToolResultBlockParam(
                toolUseId: block.id,
                content: .text(String(describing: error)),
                isError: true
            )
        }
    }
}
