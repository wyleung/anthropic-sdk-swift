import Anthropic

/// A coordinator topology: the primary thread orchestrates work by spawning session threads, each running
/// an agent from `agents`. Ported from `beta_managed_agents_multiagent_coordinator_params.py`.
///
/// 1-20 entries; each is an agent ID string, a versioned `{"type":"agent","id","version"}` reference, or
/// `{"type":"self"}` for recursive self-invocation (at most one). Entries must reference distinct,
/// existing, un-archived agents that don't themselves set `multiagent` (depth limit 1).
public struct BetaManagedAgentsMultiagentCoordinatorParams: Encodable, Sendable, Equatable {
    public let agents: [BetaManagedAgentsMultiagentRosterEntryParams]
    public let type = "coordinator"

    public init(agents: [BetaManagedAgentsMultiagentRosterEntryParams]) {
        self.agents = agents
    }
}

/// An agent's multiagent configuration to set. Ported from `beta_managed_agents_multiagent_params.py`,
/// which became a two-way union: the original `coordinator` roster, or `multiagent_20261001`.
public enum BetaManagedAgentsMultiagentParams: Sendable, Equatable {
    case coordinator(BetaManagedAgentsMultiagentCoordinatorParams)
    case multiagent20261001(BetaManagedAgentsMultiagent20261001Params)

    /// A coordinator roster -- the only form before `multiagent_20261001`, kept so existing call sites compile.
    public init(agents: [BetaManagedAgentsMultiagentRosterEntryParams]) {
        self = .coordinator(BetaManagedAgentsMultiagentCoordinatorParams(agents: agents))
    }
}

extension BetaManagedAgentsMultiagentParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .coordinator(let value): try value.encode(to: encoder)
        case .multiagent20261001(let value): try value.encode(to: encoder)
        }
    }
}

/// `multiagent_20261001`: three members, each enabled or disabled on its own. Ported from
/// `beta_managed_agents_multiagent20261001_params.py`.
///
/// **Omitted, versus `.useDefault`, matters on update.** If the agent's stored `multiagent` is also
/// `multiagent_20261001`, this configuration is *merged* into it level by level instead of replacing it:
/// a member you leave `nil` keeps its stored value, while `.useDefault` (sent as JSON `null`) takes its
/// default -- advisor disabled, subagents enabled, workflows enabled. On create, `nil` and `.useDefault`
/// both mean the default.
public struct BetaManagedAgentsMultiagent20261001Params: Encodable, Sendable, Equatable {
    public let type = "multiagent_20261001"
    public let advisor: BetaManagedAgentsMultiagentAdvisorParams?
    public let subagents: BetaManagedAgentsMultiagentSubagentsParams?
    public let workflows: BetaManagedAgentsMultiagentWorkflowsParams?

    public init(
        advisor: BetaManagedAgentsMultiagentAdvisorParams? = nil,
        subagents: BetaManagedAgentsMultiagentSubagentsParams? = nil,
        workflows: BetaManagedAgentsMultiagentWorkflowsParams? = nil
    ) {
        self.advisor = advisor
        self.subagents = subagents
        self.workflows = workflows
    }
}

private enum ToggleKeys: String, CodingKey {
    case type, model, inlineAgents, predefinedAgents
}

/// Whether the session's primary thread can consult an advisor model. Ported from
/// `beta_managed_agents_multiagent_advisor_params.py`. `.useDefault` encodes JSON `null`.
public enum BetaManagedAgentsMultiagentAdvisorParams: Sendable, Equatable {
    /// The primary thread can consult `model` mid-turn; it must be permitted as an advisor for the agent's model.
    case enabled(model: String)
    case disabled
    /// Reset this member to its default (disabled), sent as `null`.
    case useDefault
}

extension BetaManagedAgentsMultiagentAdvisorParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let model):
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("enabled", forKey: .type)
            try container.encode(model, forKey: .model)
        case .disabled:
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("disabled", forKey: .type)
        case .useDefault:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

/// Whether agents can define inline (unsaved) agents. Ported from
/// `beta_managed_agents_multiagent_inline_agents_params.py`. `.useDefault` encodes JSON `null`.
public enum BetaManagedAgentsMultiagentInlineAgentsParams: Sendable, Equatable {
    case enabled
    case disabled
    /// Reset to the default (enabled), sent as `null`.
    case useDefault
}

extension BetaManagedAgentsMultiagentInlineAgentsParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled:
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("enabled", forKey: .type)
        case .disabled:
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("disabled", forKey: .type)
        case .useDefault:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

/// A saved agent a subagent or workflow may use. Ported from
/// `beta_managed_agents_multiagent_predefined_agent_params.py`: an agent ID string, a versioned
/// reference, or `self`.
public enum BetaManagedAgentsMultiagentPredefinedAgentParams: Sendable, Equatable {
    case id(String)
    case agent(BetaManagedAgentsAgentParams)
    case selfAgent(BetaManagedAgentsMultiagentSelfParams)
}

extension BetaManagedAgentsMultiagentPredefinedAgentParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .agent(let value): try value.encode(to: encoder)
        case .selfAgent(let value): try value.encode(to: encoder)
        }
    }
}

/// Whether the agent can spawn session threads, each running a predefined agent (listed in
/// `predefinedAgents`, at most 20) or an inline one. Ported from
/// `beta_managed_agents_multiagent_subagents_params.py`. If inline agents are disabled, `predefinedAgents`
/// must name at least one. `nil` and `[]` both mean no predefined agents; this list is separate from
/// `workflows.predefinedAgents`. `.useDefault` encodes JSON `null`.
public enum BetaManagedAgentsMultiagentSubagentsParams: Sendable, Equatable {
    case enabled(
        inlineAgents: BetaManagedAgentsMultiagentInlineAgentsParams? = nil,
        predefinedAgents: [BetaManagedAgentsMultiagentPredefinedAgentParams]? = nil
    )
    case disabled
    /// Reset to the default (enabled), sent as `null`.
    case useDefault
}

extension BetaManagedAgentsMultiagentSubagentsParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let inlineAgents, let predefinedAgents):
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("enabled", forKey: .type)
            try container.encodeIfPresent(inlineAgents, forKey: .inlineAgents)
            try container.encodeIfPresent(predefinedAgents, forKey: .predefinedAgents)
        case .disabled:
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("disabled", forKey: .type)
        case .useDefault:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

/// Whether the agent can start workflow runs, each following a plan the agent writes. Same shape as
/// subagents, with its own separate `predefinedAgents`. Ported from
/// `beta_managed_agents_multiagent_workflows_params.py`. `.useDefault` encodes JSON `null`.
public enum BetaManagedAgentsMultiagentWorkflowsParams: Sendable, Equatable {
    case enabled(
        inlineAgents: BetaManagedAgentsMultiagentInlineAgentsParams? = nil,
        predefinedAgents: [BetaManagedAgentsMultiagentPredefinedAgentParams]? = nil
    )
    case disabled
    /// Reset to the default (enabled), sent as `null`.
    case useDefault
}

extension BetaManagedAgentsMultiagentWorkflowsParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let inlineAgents, let predefinedAgents):
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("enabled", forKey: .type)
            try container.encodeIfPresent(inlineAgents, forKey: .inlineAgents)
            try container.encodeIfPresent(predefinedAgents, forKey: .predefinedAgents)
        case .disabled:
            var container = encoder.container(keyedBy: ToggleKeys.self)
            try container.encode("disabled", forKey: .type)
        case .useDefault:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}
