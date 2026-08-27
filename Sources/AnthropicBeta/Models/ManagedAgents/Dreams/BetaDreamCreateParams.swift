import Anthropic

/// Ported from `dream_create_params.py`. There is no `DreamListParams` struct -- per this
/// codebase's established convention (e.g. `BetaSessions.list`), list-endpoint filters flatten
/// directly into `BetaDreams.list`'s argument list instead.
public struct BetaDreamCreateParams: Encodable, Sendable, Equatable {
    public let inputs: [BetaDreamInputParam]
    public let model: BetaDreamModelParam
    public let instructions: String?
    public let outputBehavior: BetaOutputBehaviorParam?

    public init(
        inputs: [BetaDreamInputParam],
        model: BetaDreamModelParam,
        instructions: String? = nil,
        outputBehavior: BetaOutputBehaviorParam? = nil
    ) {
        self.inputs = inputs
        self.model = model
        self.instructions = instructions
        self.outputBehavior = outputBehavior
    }
}
