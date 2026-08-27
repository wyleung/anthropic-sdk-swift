import Anthropic

/// A hard spend ceiling: the session stops issuing new model requests once the tracked list cost
/// reaches `maxListCost`. Ported from `beta_managed_agents_budget_limit.py`. The `type` field is
/// always the literal `"limit"`.
public struct BetaManagedAgentsBudgetLimit: Codable, Sendable, Equatable {
    public let maxListCost: BetaMonetaryAmount
    public let type: String

    public init(maxListCost: BetaMonetaryAmount, type: String = "limit") {
        self.maxListCost = maxListCost
        self.type = type
    }
}

/// Request-side counterpart to `BetaManagedAgentsBudgetLimit`. Ported from
/// `beta_managed_agents_budget_limit_param.py`.
public struct BetaManagedAgentsBudgetLimitParams: Encodable, Sendable, Equatable {
    public let maxListCost: BetaMonetaryAmountParams
    public let type = "limit"

    public init(maxListCost: BetaMonetaryAmountParams) {
        self.maxListCost = maxListCost
    }
}
