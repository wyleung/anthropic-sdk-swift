import Anthropic

/// Resolved `multiagent_20261001` configuration: three members, each enabled or disabled on its own.
/// Ported from `beta_managed_agents_multiagent20261001.py`.
public struct BetaManagedAgentsMultiagent20261001: Codable, Sendable, Equatable {
    /// Whether the session's primary thread can consult an advisor model.
    public let advisor: BetaManagedAgentsMultiagentAdvisor
    /// Whether the agent can spawn session threads.
    public let subagents: BetaManagedAgentsMultiagentSubagents
    public let type: String
    /// Whether the agent can start workflow runs.
    public let workflows: BetaManagedAgentsMultiagentWorkflows
}

/// Whether agents may define inline agents -- agents with no saved Agent resource. Ported from
/// `beta_managed_agents_multiagent_inline_agents.py` and its `_enabled`/`_disabled` variants, which carry
/// nothing but the discriminator.
public enum BetaManagedAgentsMultiagentInlineAgents: Sendable, Equatable {
    case enabled
    case disabled
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMultiagentInlineAgents: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "enabled": self = .enabled
        case "disabled": self = .disabled
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(_, let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var container = encoder.container(keyedBy: DiscriminatorKeys.self)
        try container.encode(self == .enabled ? "enabled" : "disabled", forKey: .type)
    }
}

/// The session's primary thread can consult `model` mid-turn. Ported from
/// `beta_managed_agents_multiagent_advisor_enabled.py`.
public struct BetaManagedAgentsMultiagentAdvisorEnabled: Codable, Sendable, Equatable {
    public let model: String
    public let type: String

    public init(model: String, type: String = "enabled") {
        self.model = model
        self.type = type
    }
}

/// Ported from `beta_managed_agents_multiagent_advisor.py`.
public enum BetaManagedAgentsMultiagentAdvisor: Sendable, Equatable {
    case enabled(BetaManagedAgentsMultiagentAdvisorEnabled)
    case disabled
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMultiagentAdvisor: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "enabled": self = .enabled(try BetaManagedAgentsMultiagentAdvisorEnabled(from: decoder))
        case "disabled": self = .disabled
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let value):
            try value.encode(to: encoder)
        case .disabled:
            var container = encoder.container(keyedBy: DiscriminatorKeys.self)
            try container.encode("disabled", forKey: .type)
        case .unknown(_, let raw):
            try raw.encode(to: encoder)
        }
    }
}

/// The agent can spawn session threads, each running a predefined agent (a saved agent listed in
/// `predefinedAgents`) or an inline agent. Ported from `beta_managed_agents_multiagent_subagents_enabled.py`.
public struct BetaManagedAgentsMultiagentSubagentsEnabled: Codable, Sendable, Equatable {
    public let inlineAgents: BetaManagedAgentsMultiagentInlineAgents
    public let predefinedAgents: [BetaManagedAgentsAgentReference]
    public let type: String
}

/// The agent can start workflow runs, each following a plan the agent writes. Separate from subagents: an
/// agent in `subagents.predefinedAgents` is not added here, nor the reverse. Ported from
/// `beta_managed_agents_multiagent_workflows_enabled.py`.
public struct BetaManagedAgentsMultiagentWorkflowsEnabled: Codable, Sendable, Equatable {
    public let inlineAgents: BetaManagedAgentsMultiagentInlineAgents
    public let predefinedAgents: [BetaManagedAgentsAgentReference]
    public let type: String
}

/// Ported from `beta_managed_agents_multiagent_subagents.py`.
public enum BetaManagedAgentsMultiagentSubagents: Sendable, Equatable {
    case enabled(BetaManagedAgentsMultiagentSubagentsEnabled)
    case disabled
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMultiagentSubagents: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "enabled": self = .enabled(try BetaManagedAgentsMultiagentSubagentsEnabled(from: decoder))
        case "disabled": self = .disabled
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let value):
            try value.encode(to: encoder)
        case .disabled:
            var container = encoder.container(keyedBy: DiscriminatorKeys.self)
            try container.encode("disabled", forKey: .type)
        case .unknown(_, let raw):
            try raw.encode(to: encoder)
        }
    }
}

/// Ported from `beta_managed_agents_multiagent_workflows.py`.
public enum BetaManagedAgentsMultiagentWorkflows: Sendable, Equatable {
    case enabled(BetaManagedAgentsMultiagentWorkflowsEnabled)
    case disabled
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMultiagentWorkflows: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "enabled": self = .enabled(try BetaManagedAgentsMultiagentWorkflowsEnabled(from: decoder))
        case "disabled": self = .disabled
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let value):
            try value.encode(to: encoder)
        case .disabled:
            var container = encoder.container(keyedBy: DiscriminatorKeys.self)
            try container.encode("disabled", forKey: .type)
        case .unknown(_, let raw):
            try raw.encode(to: encoder)
        }
    }
}
