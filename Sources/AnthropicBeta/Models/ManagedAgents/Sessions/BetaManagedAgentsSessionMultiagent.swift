import Anthropic

/// An agent defined inline -- in a workflow run's plan or when a session thread is spawned -- so it has
/// no Agent resource, and no `id` or `version`. Ported from `sessions/beta_managed_agents_inline_agent.py`.
public struct BetaManagedAgentsInlineAgent: Codable, Sendable, Equatable {
    public let description: String?
    /// The session's execution principal. Optional only because it postdates this port.
    public let executionIdentity: BetaManagedAgentsExecutionIdentity?
    public let mcpServers: [BetaManagedAgentsMCPServerURLDefinition]
    public let model: BetaManagedAgentsModelConfig
    /// The name the agent's definition gave, or one the server assigned.
    public let name: String
    public let skills: [BetaManagedAgentsSkill]
    public let system: String?
    public let tools: [BetaManagedAgentsAgentTool]
    public let type: String
}

/// Session-level `multiagent_20261001`: like the agent's, but a predefined agent is resolved to the full
/// thread agent snapshotted at session creation, not a bare reference. Ported from
/// `beta_managed_agents_session_multiagent20261001.py`.
public struct BetaManagedAgentsSessionMultiagent20261001: Codable, Sendable, Equatable {
    public let advisor: BetaManagedAgentsMultiagentAdvisor
    public let subagents: BetaManagedAgentsSessionMultiagentSubagents
    public let type: String
    public let workflows: BetaManagedAgentsSessionMultiagentWorkflows
}

/// Ported from `beta_managed_agents_session_multiagent_subagents_enabled.py`.
public struct BetaManagedAgentsSessionMultiagentSubagentsEnabled: Codable, Sendable, Equatable {
    public let inlineAgents: BetaManagedAgentsMultiagentInlineAgents
    public let predefinedAgents: [BetaManagedAgentsSessionThreadAgent]
    public let type: String
}

/// Ported from `beta_managed_agents_session_multiagent_workflows_enabled.py`.
public struct BetaManagedAgentsSessionMultiagentWorkflowsEnabled: Codable, Sendable, Equatable {
    public let inlineAgents: BetaManagedAgentsMultiagentInlineAgents
    public let predefinedAgents: [BetaManagedAgentsSessionThreadAgent]
    public let type: String
}

/// Ported from `beta_managed_agents_session_multiagent_subagents.py` (its disabled variant is shared
/// with the agent-level one).
public enum BetaManagedAgentsSessionMultiagentSubagents: Sendable, Equatable {
    case enabled(BetaManagedAgentsSessionMultiagentSubagentsEnabled)
    case disabled
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionMultiagentSubagents: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "enabled": self = .enabled(try BetaManagedAgentsSessionMultiagentSubagentsEnabled(from: decoder))
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

/// Ported from `beta_managed_agents_session_multiagent_workflows.py`.
public enum BetaManagedAgentsSessionMultiagentWorkflows: Sendable, Equatable {
    case enabled(BetaManagedAgentsSessionMultiagentWorkflowsEnabled)
    case disabled
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionMultiagentWorkflows: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "enabled": self = .enabled(try BetaManagedAgentsSessionMultiagentWorkflowsEnabled(from: decoder))
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

/// A session's multiagent configuration. Ported from `beta_managed_agents_session_multiagent.py`: the
/// original `coordinator` roster, or `multiagent_20261001`.
public enum BetaManagedAgentsSessionMultiagent: Sendable, Equatable {
    case coordinator(BetaManagedAgentsSessionMultiagentCoordinator)
    case multiagent20261001(BetaManagedAgentsSessionMultiagent20261001)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionMultiagent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "coordinator": self = .coordinator(try BetaManagedAgentsSessionMultiagentCoordinator(from: decoder))
        case "multiagent_20261001":
            self = .multiagent20261001(try BetaManagedAgentsSessionMultiagent20261001(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .coordinator(let value): try value.encode(to: encoder)
        case .multiagent20261001(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
