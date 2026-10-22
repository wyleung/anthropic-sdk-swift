/// Compacts the whole conversation and returns a signed `compaction` block, alone, that a later request
/// sends back first in `messages` in place of the messages it summarizes. Ported from
/// `types/beta/beta_compaction_config_param.py`. There is no trigger and no pause flag: sending the
/// parameter compacts, and nothing is sampled after the block.
public struct BetaCompactionConfigParam: Encodable, Sendable, Equatable {
    public let type = "summarize"
    /// Replaces the server's default summarization prompt for this request. A value that is empty or
    /// only whitespace counts as absent.
    public let instructions: String?

    public init(instructions: String? = nil) {
        self.instructions = instructions
    }
}
