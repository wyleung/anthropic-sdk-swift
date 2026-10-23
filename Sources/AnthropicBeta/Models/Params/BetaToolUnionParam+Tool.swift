import Anthropic

extension BetaToolUnionParam {
    /// The `tools` entry that declares `tool` to the model, so a tool defined once for
    /// ``BetaToolRunner`` can also go straight into a request you send yourself -- `beta.messages.create`,
    /// `stream` or `countTokens` -- without restating its name, description and schema. Only the
    /// declaration is sent; running the tool stays your job (or the runner's).
    public init(_ tool: some AnthropicTool) {
        self.init(AnyAnthropicTool(tool))
    }

    public init(_ tool: AnyAnthropicTool) {
        self = .tool(ToolUnionParam(tool))
    }
}
