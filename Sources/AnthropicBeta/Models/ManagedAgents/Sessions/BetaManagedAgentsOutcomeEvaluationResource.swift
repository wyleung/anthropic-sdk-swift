import Anthropic

/// Evaluation state for a single outcome defined via a `user.define_outcome` event. Ported from
/// `beta_managed_agents_outcome_evaluation_resource.py`. `result` is left as a plain `String`
/// (`"pending"`/`"running"`/`"evaluating"`/terminal states like `"satisfied"`,
/// `"max_iterations_reached"`, `"failed"`, `"interrupted"`) rather than a closed enum, matching
/// this port's treatment of other server-driven state strings not modeled as `Literal` unions in
/// the Python source.
public struct BetaManagedAgentsOutcomeEvaluationResource: Codable, Sendable, Equatable {
    public let completedAt: String?
    public let description: String
    public let explanation: String?
    public let iteration: Int
    public let outcomeId: String
    public let result: String
    public let type: String

    public init(
        completedAt: String? = nil,
        description: String,
        explanation: String? = nil,
        iteration: Int,
        outcomeId: String,
        result: String,
        type: String = "outcome_evaluation"
    ) {
        self.completedAt = completedAt
        self.description = description
        self.explanation = explanation
        self.iteration = iteration
        self.outcomeId = outcomeId
        self.result = result
        self.type = type
    }
}
