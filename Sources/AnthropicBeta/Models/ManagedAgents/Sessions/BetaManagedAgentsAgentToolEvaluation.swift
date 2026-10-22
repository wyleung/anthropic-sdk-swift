import Anthropic

/// Ported from `sessions/beta_managed_agents_agent_auto_evaluated_permission_allow.py`: the server judged
/// the invocation safe to execute without client approval.
public struct BetaManagedAgentsAgentAutoEvaluatedPermissionAllow: Codable, Sendable, Equatable {
    public let type = "allow"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// Ported from `sessions/beta_managed_agents_agent_auto_evaluated_permission_ask.py`: the server could not
/// reach a judgement, so the call waits for the client.
public struct BetaManagedAgentsAgentAutoEvaluatedPermissionAsk: Codable, Sendable, Equatable {
    public let type = "ask"
    public let reasonCode: String

    private enum CodingKeys: String, CodingKey {
        case type, reasonCode
    }
}

/// Ported from `sessions/beta_managed_agents_agent_auto_evaluated_permission_deny.py`: the server judged the
/// invocation high-risk; it does not execute and a synthetic error tool result is appended.
public struct BetaManagedAgentsAgentAutoEvaluatedPermissionDeny: Codable, Sendable, Equatable {
    public let type = "deny"
    public let reasonCode: String

    private enum CodingKeys: String, CodingKey {
        case type, reasonCode
    }
}

/// How the server judged one invocation under an `auto` permission policy. Ported from
/// `sessions/beta_managed_agents_agent_auto_evaluated_permission.py`.
public enum BetaManagedAgentsAgentAutoEvaluatedPermission: Sendable, Equatable {
    case allow(BetaManagedAgentsAgentAutoEvaluatedPermissionAllow)
    case ask(BetaManagedAgentsAgentAutoEvaluatedPermissionAsk)
    case deny(BetaManagedAgentsAgentAutoEvaluatedPermissionDeny)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsAgentAutoEvaluatedPermission: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "allow": self = .allow(try BetaManagedAgentsAgentAutoEvaluatedPermissionAllow(from: decoder))
        case "ask": self = .ask(try BetaManagedAgentsAgentAutoEvaluatedPermissionAsk(from: decoder))
        case "deny": self = .deny(try BetaManagedAgentsAgentAutoEvaluatedPermissionDeny(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .allow(let value): try value.encode(to: encoder)
        case .ask(let value): try value.encode(to: encoder)
        case .deny(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// The resolved `permission_policy` was `always_allow`; accompanies `evaluatedPermission == .allow`.
public struct BetaManagedAgentsAgentToolEvaluationAlwaysAllow: Codable, Sendable, Equatable {
    public let type = "always_allow"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// The resolved `permission_policy` was `always_ask`; accompanies `evaluatedPermission == .ask`.
public struct BetaManagedAgentsAgentToolEvaluationAlwaysAsk: Codable, Sendable, Equatable {
    public let type = "always_ask"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// The resolved `permission_policy` was `auto`: the server judged this invocation individually.
public struct BetaManagedAgentsAgentToolEvaluationAuto: Codable, Sendable, Equatable {
    public let type = "auto"
    public let evaluatedPermission: BetaManagedAgentsAgentAutoEvaluatedPermission

    private enum CodingKeys: String, CodingKey {
        case type, evaluatedPermission
    }
}

/// Which policy produced a tool call's `evaluatedPermission`, and for `auto` the server's reasoning.
/// Ported from `sessions/beta_managed_agents_agent_tool_evaluation.py`.
public enum BetaManagedAgentsAgentToolEvaluation: Sendable, Equatable {
    case alwaysAllow(BetaManagedAgentsAgentToolEvaluationAlwaysAllow)
    case alwaysAsk(BetaManagedAgentsAgentToolEvaluationAlwaysAsk)
    case auto(BetaManagedAgentsAgentToolEvaluationAuto)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsAgentToolEvaluation: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "always_allow": self = .alwaysAllow(try BetaManagedAgentsAgentToolEvaluationAlwaysAllow(from: decoder))
        case "always_ask": self = .alwaysAsk(try BetaManagedAgentsAgentToolEvaluationAlwaysAsk(from: decoder))
        case "auto": self = .auto(try BetaManagedAgentsAgentToolEvaluationAuto(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .alwaysAllow(let value): try value.encode(to: encoder)
        case .alwaysAsk(let value): try value.encode(to: encoder)
        case .auto(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
