import Anthropic

/// Ported from `session_update_params.py`. Every field is a PATCH-merge: omitting a Swift
/// initializer argument (`nil`) leaves the outer property `nil`, which Swift's synthesized
/// `Encodable` conformance omits from the JSON body entirely (preserves the existing value
/// server-side). None of these fields document tri-state (omit/null/value) clear semantics at the
/// top level, so all are plain 2-state `T?` -- contrast `metadata`, whose *values* are individually
/// nullable to delete that key (`[String: String?]?`), matching `BetaEnvironmentUpdateParams`.
public struct BetaSessionUpdateParams: Encodable, Sendable, Equatable {
    public var agent: BetaManagedAgentsSessionAgentUpdateParam?
    public var budget: BetaManagedAgentsBudgetLimitParams?
    public var metadata: [String: String?]?
    public var title: String?
    public var vaultIds: [String]?

    public init(
        agent: BetaManagedAgentsSessionAgentUpdateParam? = nil,
        budget: BetaManagedAgentsBudgetLimitParams? = nil,
        metadata: [String: String?]? = nil,
        title: String? = nil,
        vaultIds: [String]? = nil
    ) {
        self.agent = agent
        self.budget = budget
        self.metadata = metadata
        self.title = title
        self.vaultIds = vaultIds
    }
}
