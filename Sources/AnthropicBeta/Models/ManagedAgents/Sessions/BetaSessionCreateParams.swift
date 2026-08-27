import Anthropic

/// Ported from the `Agent` union local to `session_create_params.py` -- a bare `agent` ID string
/// (pins the latest version), a full inline `BetaManagedAgentsAgentParams`, or an
/// `BetaManagedAgentsAgentWithOverridesParams` referencing an existing agent with per-session
/// overrides. Mirrors `MessageCreateParamsContainerParam`'s bare-value-or-object union pattern.
public enum BetaManagedAgentsSessionAgentParam: Sendable, Equatable {
    case id(String)
    case agent(BetaManagedAgentsAgentParams)
    case agentWithOverrides(BetaManagedAgentsAgentWithOverridesParams)
}

extension BetaManagedAgentsSessionAgentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .id(let value): try container.encode(value)
        case .agent(let value): try container.encode(value)
        case .agentWithOverrides(let value): try container.encode(value)
        }
    }
}

extension BetaManagedAgentsSessionAgentParam: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .id(value)
    }
}

/// Ported from `session_create_params.py`. All fields besides `agent`/`environmentId` are optional
/// and simply omitted from the request body when `nil` -- there's no PATCH-style clear semantics on
/// create (see `BetaSessionUpdateParams` for that).
public struct BetaSessionCreateParams: Encodable, Sendable, Equatable {
    public let agent: BetaManagedAgentsSessionAgentParam
    public let environmentId: String
    public let budget: BetaManagedAgentsBudgetLimitParams?
    public let initialEvents: [BetaManagedAgentsInitialEventParam]?
    public let metadata: [String: String]?
    public let resources: [BetaManagedAgentsSessionResourceParam]?
    public let title: String?
    public let vaultIds: [String]?

    public init(
        agent: BetaManagedAgentsSessionAgentParam,
        environmentId: String,
        budget: BetaManagedAgentsBudgetLimitParams? = nil,
        initialEvents: [BetaManagedAgentsInitialEventParam]? = nil,
        metadata: [String: String]? = nil,
        resources: [BetaManagedAgentsSessionResourceParam]? = nil,
        title: String? = nil,
        vaultIds: [String]? = nil
    ) {
        self.agent = agent
        self.environmentId = environmentId
        self.budget = budget
        self.initialEvents = initialEvents
        self.metadata = metadata
        self.resources = resources
        self.title = title
        self.vaultIds = vaultIds
    }
}
