import Foundation

/// Drives the call -> execute-tools -> loop cycle for a fixed registry of custom `AnthropicTool`s,
/// so callers don't have to hand-write the `while` loop themselves. Mirrors the language-independent
/// loop shared by the Python (`BetaToolRunner`) and TypeScript (`BetaToolRunner`) reference SDKs:
///
/// - Call `messages.create`, then decide what to do from the turn's `stop_reason`, as the reference
///   runners do (``Step``):
///   - `tool_use`: execute every `tool_use` block concurrently (a `TaskGroup`, matching the TS
///     runner's `Promise.all`) and batch all resulting `tool_result` blocks into one
///     `{role: "user", ...}` message, in original `tool_use` order, before looping. Stop if the turn
///     has no `tool_use` blocks.
///   - `pause_turn`: the turn is unfinished (a server tool hit its iteration limit). Send it back
///     unchanged, running no tools, so the server continues it.
///   - anything else -- `end_turn`, `max_tokens`, `stop_sequence`, `model_context_window_exceeded`,
///     `refusal`, or a value this SDK doesn't know -- stop **without executing any `tool_use` block**
///     from that turn. A `max_tokens` turn can end in a truncated tool call, and a refusal means the
///     model never confirmed the side effects; neither can be replayed coherently afterward.
///
/// Not `Sendable` and not safe to `run()` concurrently from multiple tasks -- like both reference
/// SDKs' runner classes, one `ToolRunner` drives one linear conversation.
public final class ToolRunner {
    private let client: AnthropicClient
    private let toolsByName: [String: AnyAnthropicTool]
    private let options: RequestOptions
    private let maxIterations: Int?

    private var params: MessageCreateParams
    private var lastMessage: Message?

    /// Runs immediately before every `messages.create` call; lets a caller inspect or rewrite the
    /// request (e.g. trimming history) each turn. Mirrors `set_messages_params`/an equivalent hook.
    public var beforeRequest: ((MessageCreateParams) -> MessageCreateParams)?
    /// Runs after the assistant turn and tool executions are batched into their two messages, right
    /// before they're appended to the conversation. Mirrors `append_messages`.
    public var onAppendMessages: (([MessageParam]) -> Void)?
    /// Runs on the batched `{role: "user", ...}` tool-result message before it's appended, letting a
    /// caller rewrite it (e.g. to add `cache_control`). Mirrors `generate_tool_call_response`.
    public var onToolCallResponse: ((MessageParam) -> MessageParam)?

    public init(
        client: AnthropicClient,
        params: MessageCreateParams,
        tools: [AnyAnthropicTool],
        options: RequestOptions = RequestOptions(),
        maxIterations: Int? = nil
    ) {
        self.client = client
        self.toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { _, latest in latest })
        self.options = options
        self.maxIterations = maxIterations
        self.params = params.with(tools: (params.tools ?? []) + tools.map { .custom($0.toolParam) })
    }

    /// Runs the loop to completion -- until the model stops requesting tool calls, issues a
    /// refusal, or `maxIterations` is reached -- and returns the final `Message`.
    public func run() async throws -> Message {
        var iterations = 0
        while maxIterations.map({ iterations < $0 }) ?? true {
            iterations += 1

            var requestParams = params
            if let beforeRequest {
                requestParams = beforeRequest(requestParams)
            }
            let message = try await client.messages.create(requestParams, options: options)
            lastMessage = message

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

            let toolResults = await Self.executeToolUseBlocks(toolUseBlocks, toolsByName: toolsByName)
            var toolResultMessage = MessageParam(
                role: .user,
                content: toolResults.map { .toolResult($0) }
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
                message: "ToolRunner stopped without ever receiving a response from the server.",
                body: nil
            )
        }
        return lastMessage
    }

    /// What the loop does with a finished turn.
    enum Step: Equatable {
        case runTools, resume, stop
    }

    /// Every stop reason maps to exactly one step. `nil` and values this SDK doesn't know yet end the
    /// loop like any other finished turn rather than throwing.
    static func step(after stopReason: StopReason?) -> Step {
        switch stopReason {
        case .toolUse: return .runTools
        case .pauseTurn: return .resume
        case .endTurn, .maxTokens, .stopSequence, .refusal, .modelContextWindowExceeded, .unknown, nil: return .stop
        }
    }

    private static func executeToolUseBlocks(
        _ blocks: [ToolUseBlock],
        toolsByName: [String: AnyAnthropicTool]
    ) async -> [ToolResultBlockParam] {
        await withTaskGroup(of: (Int, ToolResultBlockParam).self) { group in
            for (index, block) in blocks.enumerated() {
                group.addTask { (index, await executeSingle(block, toolsByName: toolsByName)) }
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
        toolsByName: [String: AnyAnthropicTool]
    ) async -> ToolResultBlockParam {
        guard let tool = toolsByName[block.name] else {
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
