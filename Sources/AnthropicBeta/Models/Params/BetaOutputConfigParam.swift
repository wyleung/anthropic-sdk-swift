import Anthropic

/// Ported from `types/beta/beta_output_config_param.py`. Reuses GA's `EffortLevel` and
/// `JSONOutputFormatParam` directly (both field-identical to their Beta counterparts).
/// `taskBudget` corresponds to `BetaTokenTaskBudgetParam`, kept as a raw `JSONValue` passthrough
/// rather than a dedicated type for this slice.
public struct BetaOutputConfigParam: Encodable, Sendable, Equatable {
    public let effort: EffortLevel?
    public let format: JSONOutputFormatParam?
    public let taskBudget: JSONValue?

    public init(effort: EffortLevel? = nil, format: JSONOutputFormatParam? = nil, taskBudget: JSONValue? = nil) {
        self.effort = effort
        self.format = format
        self.taskBudget = taskBudget
    }
}
