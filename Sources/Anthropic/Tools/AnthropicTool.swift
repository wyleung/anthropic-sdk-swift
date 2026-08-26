/// A tool result, either as a single text block or as a list of typed content blocks --
/// mirrors `BetaToolResultContentBlockParam | str` in the Python/TS tool runners.
public enum ToolOutput: Sendable, Equatable {
    case text(String)
    case blocks([ToolResultContentBlockParam])
}

extension ToolOutput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension ToolOutput {
    /// `package` rather than `internal` so `AnthropicBeta`'s `BetaToolRunner` can reuse this
    /// instead of duplicating it.
    package var asToolResultContent: ToolResultContentParam {
        switch self {
        case .text(let text): return .text(text)
        case .blocks(let blocks): return .blocks(blocks)
        }
    }
}

/// Thrown by an `AnthropicTool.run` implementation to control exactly what `ToolRunner` reports
/// back to the model as an error result, instead of letting the loop render a caught error's
/// description. Ported from `ToolError` in both reference SDKs.
public struct ToolError: Error, Sendable, Equatable {
    public let content: ToolOutput

    public init(_ content: ToolOutput) {
        self.content = content
    }

    public init(_ text: String) {
        self.content = .text(text)
    }

    public init(_ blocks: [ToolResultContentBlockParam]) {
        self.content = .blocks(blocks)
    }
}

/// Per-invocation identity passed to `AnthropicTool.run`, replacing the reference SDKs'
/// abort-signal/cancellation-token field -- Swift's structured concurrency already propagates
/// task cancellation to a running tool without needing a signal threaded through by hand.
public struct ToolRunContext: Sendable, Equatable {
    public let toolUseId: String
    public let toolName: String

    public init(toolUseId: String, toolName: String) {
        self.toolUseId = toolUseId
        self.toolName = toolName
    }
}

/// A single custom tool `ToolRunner` can call. There's no reflection over free-function
/// parameter names in Swift, so (unlike the decorator/Zod-based reference SDKs) the JSON Schema
/// must be supplied explicitly.
public protocol AnthropicTool: Sendable {
    var name: String { get }
    var description: String? { get }
    var inputSchema: JSONValue { get }

    func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput
}

extension AnthropicTool {
    public var description: String? { nil }
}

/// Type-erased `AnthropicTool`, so `ToolRunner` can hold a heterogeneous registry of tools with
/// different concrete input-handling logic in one `[AnyAnthropicTool]`/`[String: AnyAnthropicTool]`.
public struct AnyAnthropicTool: Sendable {
    public let name: String
    public let description: String?
    public let inputSchema: JSONValue

    private let runClosure: @Sendable (JSONValue, ToolRunContext) async throws -> ToolOutput

    public init<T: AnthropicTool>(_ tool: T) {
        self.name = tool.name
        self.description = tool.description
        self.inputSchema = tool.inputSchema
        self.runClosure = { input, context in try await tool.run(input, context: context) }
    }

    public func run(_ input: JSONValue, context: ToolRunContext) async throws -> ToolOutput {
        try await runClosure(input, context)
    }

    /// `package` rather than `internal` so `AnthropicBeta`'s `BetaToolRunner` can splice tools
    /// into `BetaToolUnionParam.tool(.custom(...))` the same way GA's `ToolRunner` does.
    package var toolParam: ToolParam {
        ToolParam(name: name, inputSchema: inputSchema, description: description)
    }
}
