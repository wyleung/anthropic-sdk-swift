import Foundation

/// Drives the call -> execute-tools -> loop cycle for a fixed registry of custom `AnthropicTool`s,
/// so callers don't have to hand-write the `while` loop themselves. Mirrors the language-independent
/// loop shared by the Python (`BetaToolRunner`) and TypeScript (`BetaToolRunner`) reference SDKs:
///
/// - Call `messages.create`.
/// - Stop immediately on `stop_reason == "refusal"` without executing any `tool_use` blocks from
///   that turn -- the model never confirmed the side effects, and the results couldn't be replayed
///   coherently afterward.
/// - Stop if the turn has no `tool_use` blocks.
/// - Otherwise execute every `tool_use` block concurrently (a `TaskGroup`, matching the TS runner's
///   `Promise.all`) and batch all resulting `tool_result` blocks into one `{role: "user", ...}`
///   message, in original `tool_use` order, before looping.
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

            if message.stopReason == .refusal {
                break
            }

            let toolUseBlocks = message.content.compactMap { block -> ToolUseBlock? in
                if case .toolUse(let toolUse) = block { return toolUse }
                return nil
            }
            guard !toolUseBlocks.isEmpty else { break }

            let assistantContent = try message.content.map { try $0.asRequestParam() }
            let assistantMessage = MessageParam(role: .assistant, content: assistantContent)

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
