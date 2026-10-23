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
/// Out of scope: Python's `@beta_tool` decorator/reflection-based schema derivation -- Swift has no
/// runtime reflection over function parameters, so (like GA's `ToolRunner`) callers always supply an
/// explicit `AnthropicTool`.
///
/// Not `Sendable` and not safe to `run()` concurrently from multiple tasks -- like GA's `ToolRunner`
/// and both reference SDKs' runner classes, one `BetaToolRunner` drives one linear conversation.
public final class BetaToolRunner {
    private let client: AnthropicClient
    private let toolsByName: [String: AnyAnthropicTool]
    private let betas: [String]
    private let userProfileId: String?
    private let options: RequestOptions
    private let maxIterations: Int?

    private var params: BetaMessageCreateParams
    private var lastMessage: BetaMessage?

    /// Runs immediately before every `beta.messages.create` call; lets a caller inspect or rewrite
    /// the request (e.g. trimming history) each turn. Mirrors `set_messages_params`/an equivalent hook.
    public var beforeRequest: ((BetaMessageCreateParams) -> BetaMessageCreateParams)?
    /// Runs after the assistant turn and tool executions are batched into their two messages, right
    /// before they're appended to the conversation. Mirrors `append_messages`.
    public var onAppendMessages: (([BetaMessageParam]) -> Void)?
    /// Runs on the batched `{role: "user", ...}` tool-result message before it's appended, letting a
    /// caller rewrite it (e.g. to add `cache_control`). Mirrors `generate_tool_call_response`.
    public var onToolCallResponse: ((BetaMessageParam) -> BetaMessageParam)?

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
        self.toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { _, latest in latest })
        self.betas = betas
        self.userProfileId = userProfileId
        self.options = options
        self.maxIterations = maxIterations
        self.params = params.with(tools: (params.tools ?? []) + tools.map { .tool(.custom($0.toolParam)) })
    }

    /// Runs the loop to completion -- until the model stops requesting tool calls, issues a
    /// refusal, or `maxIterations` is reached -- and returns the final `BetaMessage`.
    public func run() async throws -> BetaMessage {
        var iterations = 0
        while maxIterations.map({ iterations < $0 }) ?? true {
            iterations += 1

            var requestParams = params
            if let beforeRequest {
                requestParams = beforeRequest(requestParams)
            }
            let message = try await client.beta.messages.create(
                requestParams, betas: betas, userProfileId: userProfileId, options: options
            )
            lastMessage = message
            propagateContainer(from: message)

            let step = Self.step(after: message.stopReason)
            if step == .stop {
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
            guard !toolUseBlocks.isEmpty else { break }

            let available = availableToolNames()
            let toolResults = await Self.executeToolUseBlocks(
                toolUseBlocks, toolsByName: toolsByName, available: available
            )
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

    /// The set of tool names dispatchable right now: every locally-registered tool, with any
    /// `tool_removal`/`tool_addition` block already in the conversation folded in, in order. Those
    /// arrive in `system` messages, and in the `toolChanges` of a `compaction` block in an `assistant`
    /// message -- which stands in for the system messages of the turns it summarized, so ignoring it
    /// would forget every tool change made before the compaction. Evaluated against `params.messages`
    /// *before* the current turn's new messages are appended, since those blocks only ever describe a
    /// change taking effect from that point in the conversation onward.
    private func availableToolNames() -> Set<String> {
        var available = Set(toolsByName.keys)
        for message in params.messages {
            for block in message.content {
                switch (message.role, block) {
                case (.system, .toolRemoval(let removal)):
                    if let name = Self.referencedToolName(removal.tool) { available.remove(name) }
                case (.system, .toolAddition(let addition)):
                    if let name = Self.addedToolName(addition.tool) { available.insert(name) }
                case (.assistant, .compaction(let compaction)):
                    for change in compaction.toolChanges ?? [] {
                        Self.apply(change, to: &available)
                    }
                default:
                    continue
                }
            }
        }
        return available
    }

    /// Only a direct-by-name reference resolves to a locally dispatchable tool. MCP references name
    /// a server-side tool or an entire server's toolset -- neither is something `toolsByName` could
    /// ever hold, so both resolve to `nil` and are ignored for local dispatch.
    private static func referencedToolName(_ reference: BetaToolChangeReferenceParam) -> String? {
        switch reference {
        case .tool(let toolReference): return toolReference.name
        case .mcpTool, .mcpToolset: return nil
        }
    }

    /// An addition names a runnable tool either by reference or, for inline tools, by the `name` its
    /// full definition carries. Not every definition has one (an `mcp_toolset` doesn't), and those are
    /// never locally runnable.
    private static func addedToolName(_ target: BetaToolAdditionParam) -> String? {
        switch target {
        case .reference(let reference): return referencedToolName(reference)
        case .definition(let definition): return definitionName(definition.definition)
        }
    }

    private static func definitionName(_ definition: BetaToolUnionParam) -> String? {
        guard let data = try? HTTPTransport.encoder.encode(definition),
              let json = try? HTTPTransport.decoder.decode(JSONValue.self, from: data)
        else { return nil }
        return json["name"]?.stringValue
    }

    private static func apply(_ change: BetaCompactionToolChangeParam, to available: inout Set<String>) {
        switch change {
        case .removal(let removal):
            if let name = referencedToolName(removal.tool) { available.remove(name) }
        case .addition(let addition):
            if let name = addedToolName(addition.tool) { available.insert(name) }
        case .raw(let json):
            // A response block's entries, echoed verbatim. Unknown change or tool types are ignored
            // rather than failing -- forward compatibility, as upstream does.
            guard let type = json["type"]?.stringValue, let tool = json["tool"] else { return }
            let name: String?
            switch tool["type"]?.stringValue {
            case "tool_reference": name = tool["name"]?.stringValue
            case "tool_definition": name = tool["definition"]?["name"]?.stringValue
            default: name = nil
            }
            guard let name else { return }
            if type == "tool_removal" { available.remove(name) } else if type == "tool_addition" { available.insert(name) }
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
        toolsByName: [String: AnyAnthropicTool],
        available: Set<String>
    ) async -> [ToolResultBlockParam] {
        await withTaskGroup(of: (Int, ToolResultBlockParam).self) { group in
            for (index, block) in blocks.enumerated() {
                group.addTask { (index, await executeSingle(block, toolsByName: toolsByName, available: available)) }
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
        toolsByName: [String: AnyAnthropicTool],
        available: Set<String>
    ) async -> ToolResultBlockParam {
        guard available.contains(block.name), let tool = toolsByName[block.name] else {
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
