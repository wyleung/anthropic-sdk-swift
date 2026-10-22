import Anthropic

/// A reference to another managed agent participating in a multiagent roster, always resolved to
/// a concrete version on the response side. Ported from `beta_managed_agents_agent_reference.py`.
public struct BetaManagedAgentsAgentReference: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let version: Int

    public init(id: String, type: String = "agent", version: Int) {
        self.id = id
        self.type = type
        self.version = version
    }
}

/// A model-only advisor participating in a multiagent roster (no dedicated agent config -- just a
/// bare model). Ported from `beta_managed_agents_advisor.py`.
public struct BetaManagedAgentsAdvisor: Codable, Sendable, Equatable {
    public let model: String
    public let type: String

    public init(model: String, type: String = "advisor") {
        self.model = model
        self.type = type
    }
}

/// Ported from the `MultiagentAgent` union in `beta_managed_agents_multiagent.py` --
/// `Union[BetaManagedAgentsAgentReference, BetaManagedAgentsAdvisor]`, discriminated on `type`.
/// Note this response-side union has no "self" case -- that sentinel only exists on the params
/// side (`BetaManagedAgentsMultiagentRosterEntryParams`) to let a create/update request refer back
/// to the agent being defined; the response always resolves roster entries to concrete agent or
/// advisor references.
public enum BetaManagedAgentsMultiagentAgent: Sendable, Equatable {
    case agent(BetaManagedAgentsAgentReference)
    case advisor(BetaManagedAgentsAdvisor)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMultiagentAgent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "agent": self = .agent(try BetaManagedAgentsAgentReference(from: decoder))
        case "advisor": self = .advisor(try BetaManagedAgentsAdvisor(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agent(let value): try value.encode(to: encoder)
        case .advisor(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// A coordinator topology: the primary thread orchestrates work by spawning session threads, each running
/// an agent from this roster. Ported from `beta_managed_agents_multiagent_coordinator.py` -- the original,
/// pre-`multiagent_20261001` shape of `multiagent`, which is now one case of `BetaManagedAgentsMultiagent`.
public struct BetaManagedAgentsMultiagentCoordinator: Codable, Sendable, Equatable {
    public let agents: [BetaManagedAgentsMultiagentAgent]
    public let type: String

    public init(agents: [BetaManagedAgentsMultiagentAgent], type: String = "coordinator") {
        self.agents = agents
        self.type = type
    }
}

/// An agent's multiagent configuration. Ported from `beta_managed_agents_multiagent.py`, which became a
/// two-way union: the original `coordinator` roster, or `multiagent_20261001`, whose three members
/// (advisor, subagents, workflows) are each enabled or disabled on their own.
public enum BetaManagedAgentsMultiagent: Sendable, Equatable {
    case coordinator(BetaManagedAgentsMultiagentCoordinator)
    case multiagent20261001(BetaManagedAgentsMultiagent20261001)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsMultiagent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "coordinator": self = .coordinator(try BetaManagedAgentsMultiagentCoordinator(from: decoder))
        case "multiagent_20261001": self = .multiagent20261001(try BetaManagedAgentsMultiagent20261001(from: decoder))
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

public struct BetaManagedAgentsAgentParams: Encodable, Sendable, Equatable {
    public let id: String
    public let type = "agent"
    public let version: Int?

    public init(id: String, version: Int? = nil) {
        self.id = id
        self.version = version
    }
}

/// Ported from `beta_managed_agents_multiagent_self_params.py` -- a sentinel with no fields beyond
/// its fixed `type`, meaning "the agent that owns this multiagent config" (lets an agent refer to
/// itself in its own roster without knowing its own ID/version ahead of creation).
public struct BetaManagedAgentsMultiagentSelfParams: Encodable, Sendable, Equatable {
    public let type = "self"

    public init() {}
}

/// Ported from `beta_managed_agents_advisor_params.py`.
public struct BetaManagedAgentsAdvisorParams: Encodable, Sendable, Equatable {
    public let model: String
    public let type = "advisor"

    public init(model: String) {
        self.model = model
    }
}

/// Ported from `beta_managed_agents_multiagent_roster_entry_params.py`'s union -- a bare agent-id
/// string (shorthand for `BetaManagedAgentsAgentParams(id:)` referencing the latest version), or
/// one of three tagged objects. Request-only (no `.unknown` fallback); each leaf already carries
/// its own fixed `type` discriminator, so `encode(to:)` is a plain switch.
public enum BetaManagedAgentsMultiagentRosterEntryParams: Sendable, Equatable {
    case id(String)
    case agent(BetaManagedAgentsAgentParams)
    case selfAgent(BetaManagedAgentsMultiagentSelfParams)
    case advisor(BetaManagedAgentsAdvisorParams)
}

extension BetaManagedAgentsMultiagentRosterEntryParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .agent(let value): try value.encode(to: encoder)
        case .selfAgent(let value): try value.encode(to: encoder)
        case .advisor(let value): try value.encode(to: encoder)
        }
    }
}

extension BetaManagedAgentsMultiagentRosterEntryParams: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .id(value)
    }
}
