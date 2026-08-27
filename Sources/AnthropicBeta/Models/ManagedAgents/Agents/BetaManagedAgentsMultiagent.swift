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

/// Ported from `beta_managed_agents_multiagent.py`. The `type` field is always the literal
/// `"coordinator"`.
public struct BetaManagedAgentsMultiagent: Codable, Sendable, Equatable {
    public let agents: [BetaManagedAgentsMultiagentAgent]
    public let type: String

    public init(agents: [BetaManagedAgentsMultiagentAgent], type: String = "coordinator") {
        self.agents = agents
        self.type = type
    }
}

/// Ported from `beta_managed_agents_agent_params.py`. `version` is optional -- "omit to reference
/// the latest version of the agent".
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

/// Ported from `beta_managed_agents_multiagent_params.py`. The `type` field is always the literal
/// `"coordinator"`.
public struct BetaManagedAgentsMultiagentParams: Encodable, Sendable, Equatable {
    public let agents: [BetaManagedAgentsMultiagentRosterEntryParams]
    public let type = "coordinator"

    public init(agents: [BetaManagedAgentsMultiagentRosterEntryParams]) {
        self.agents = agents
    }
}
