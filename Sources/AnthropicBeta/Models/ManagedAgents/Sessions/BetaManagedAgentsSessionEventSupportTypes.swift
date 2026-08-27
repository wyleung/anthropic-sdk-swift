import Anthropic

/// Shared sub-types referenced by several session event structs: retry guidance, the `session.error`
/// error union, the `StopReason` union shared by `session.status_idle`/`session.thread_status_idle`,
/// per-model-request token usage, the tool-permission enum, system-message content, and the
/// response-side rubric union echoed by `user.define_outcome`.

/// The server is retrying automatically; the client should wait. Ported from
/// `beta_managed_agents_retry_status_retrying.py`.
public struct BetaManagedAgentsRetryStatusRetrying: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "retrying") {
        self.type = type
    }
}

/// This turn is dead; queued inputs are flushed and the session returns to idle. Ported from
/// `beta_managed_agents_retry_status_exhausted.py`.
public struct BetaManagedAgentsRetryStatusExhausted: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "exhausted") {
        self.type = type
    }
}

/// The session encountered a terminal error and will transition to `terminated`. Ported from
/// `beta_managed_agents_retry_status_terminal.py`.
public struct BetaManagedAgentsRetryStatusTerminal: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "terminal") {
        self.type = type
    }
}

/// What the client should do next in response to a `session.error` sub-error. Ported from the
/// `RetryStatus` union local to each of the 8 error leaf files (byte-identical in each).
public enum BetaManagedAgentsRetryStatus: Sendable, Equatable {
    case retrying(BetaManagedAgentsRetryStatusRetrying)
    case exhausted(BetaManagedAgentsRetryStatusExhausted)
    case terminal(BetaManagedAgentsRetryStatusTerminal)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsRetryStatus: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "retrying": self = .retrying(try BetaManagedAgentsRetryStatusRetrying(from: decoder))
        case "exhausted": self = .exhausted(try BetaManagedAgentsRetryStatusExhausted(from: decoder))
        case "terminal": self = .terminal(try BetaManagedAgentsRetryStatusTerminal(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .retrying(let value): try value.encode(to: encoder)
        case .exhausted(let value): try value.encode(to: encoder)
        case .terminal(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// An unknown or unexpected error occurred during session execution. A fallback variant; clients
/// that don't recognize a new error code can match on `retryStatus`/`message` alone. Ported from
/// `beta_managed_agents_unknown_error.py`.
public struct BetaManagedAgentsUnknownError: Codable, Sendable, Equatable {
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(message: String, retryStatus: BetaManagedAgentsRetryStatus, type: String = "unknown_error") {
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// The model is currently overloaded; emitted after automatic retries are exhausted. Ported from
/// `beta_managed_agents_model_overloaded_error.py`.
public struct BetaManagedAgentsModelOverloadedError: Codable, Sendable, Equatable {
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, retryStatus: BetaManagedAgentsRetryStatus, type: String = "model_overloaded_error"
    ) {
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// The model request was rate-limited. Ported from `beta_managed_agents_model_rate_limited_error.py`.
public struct BetaManagedAgentsModelRateLimitedError: Codable, Sendable, Equatable {
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, retryStatus: BetaManagedAgentsRetryStatus, type: String = "model_rate_limited_error"
    ) {
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// A model request failed for a reason other than overload or rate-limiting. Ported from
/// `beta_managed_agents_model_request_failed_error.py`.
public struct BetaManagedAgentsModelRequestFailedError: Codable, Sendable, Equatable {
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, retryStatus: BetaManagedAgentsRetryStatus, type: String = "model_request_failed_error"
    ) {
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// Failed to connect to an MCP server. Ported from
/// `beta_managed_agents_mcp_connection_failed_error.py`.
public struct BetaManagedAgentsMCPConnectionFailedError: Codable, Sendable, Equatable {
    public let mcpServerName: String
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        mcpServerName: String, message: String, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "mcp_connection_failed_error"
    ) {
        self.mcpServerName = mcpServerName
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// Authentication to an MCP server failed. Ported from
/// `beta_managed_agents_mcp_authentication_failed_error.py`.
public struct BetaManagedAgentsMCPAuthenticationFailedError: Codable, Sendable, Equatable {
    public let mcpServerName: String
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        mcpServerName: String, message: String, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "mcp_authentication_failed_error"
    ) {
        self.mcpServerName = mcpServerName
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// The caller's organization or workspace cannot make model requests (out of credits, or spend
/// limit reached). Retrying with the same credentials will not succeed. Ported from
/// `beta_managed_agents_billing_error.py`.
public struct BetaManagedAgentsBillingError: Codable, Sendable, Equatable {
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(message: String, retryStatus: BetaManagedAgentsRetryStatus, type: String = "billing_error") {
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// An `environment_variable` credential's `auth.networking.allowed_hosts` includes a host the
/// environment's network policy does not permit. Ported from
/// `beta_managed_agents_credential_host_unreachable_error.py`.
public struct BetaManagedAgentsCredentialHostUnreachableError: Codable, Sendable, Equatable {
    public let credentialId: String
    public let message: String
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String
    public let vaultId: String

    public init(
        credentialId: String, message: String, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "credential_host_unreachable_error", vaultId: String
    ) {
        self.credentialId = credentialId
        self.message = message
        self.retryStatus = retryStatus
        self.type = type
        self.vaultId = vaultId
    }
}

/// Ported from the `Error` union local to `sessions/beta_managed_agents_session_error_event.py`.
public enum BetaManagedAgentsSessionEventError: Sendable, Equatable {
    case unknownError(BetaManagedAgentsUnknownError)
    case modelOverloaded(BetaManagedAgentsModelOverloadedError)
    case modelRateLimited(BetaManagedAgentsModelRateLimitedError)
    case modelRequestFailed(BetaManagedAgentsModelRequestFailedError)
    case mcpConnectionFailed(BetaManagedAgentsMCPConnectionFailedError)
    case mcpAuthenticationFailed(BetaManagedAgentsMCPAuthenticationFailedError)
    case billing(BetaManagedAgentsBillingError)
    case credentialHostUnreachable(BetaManagedAgentsCredentialHostUnreachableError)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionEventError: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "unknown_error": self = .unknownError(try BetaManagedAgentsUnknownError(from: decoder))
        case "model_overloaded_error":
            self = .modelOverloaded(try BetaManagedAgentsModelOverloadedError(from: decoder))
        case "model_rate_limited_error":
            self = .modelRateLimited(try BetaManagedAgentsModelRateLimitedError(from: decoder))
        case "model_request_failed_error":
            self = .modelRequestFailed(try BetaManagedAgentsModelRequestFailedError(from: decoder))
        case "mcp_connection_failed_error":
            self = .mcpConnectionFailed(try BetaManagedAgentsMCPConnectionFailedError(from: decoder))
        case "mcp_authentication_failed_error":
            self = .mcpAuthenticationFailed(try BetaManagedAgentsMCPAuthenticationFailedError(from: decoder))
        case "billing_error": self = .billing(try BetaManagedAgentsBillingError(from: decoder))
        case "credential_host_unreachable_error":
            self = .credentialHostUnreachable(try BetaManagedAgentsCredentialHostUnreachableError(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .unknownError(let value): try value.encode(to: encoder)
        case .modelOverloaded(let value): try value.encode(to: encoder)
        case .modelRateLimited(let value): try value.encode(to: encoder)
        case .modelRequestFailed(let value): try value.encode(to: encoder)
        case .mcpConnectionFailed(let value): try value.encode(to: encoder)
        case .mcpAuthenticationFailed(let value): try value.encode(to: encoder)
        case .billing(let value): try value.encode(to: encoder)
        case .credentialHostUnreachable(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// The agent completed its turn naturally and is ready for the next user message. Ported from
/// `beta_managed_agents_session_end_turn.py`.
public struct BetaManagedAgentsSessionEndTurn: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "end_turn") {
        self.type = type
    }
}

/// The agent is idle waiting on one or more blocking user-input events (tool confirmation, custom
/// tool result, etc.). Resolving all of them transitions the session back to running. Resolving
/// fewer than all re-emits `session.status_idle` with the remainder. Ported from
/// `beta_managed_agents_session_requires_action.py`.
public struct BetaManagedAgentsSessionRequiresAction: Codable, Sendable, Equatable {
    public let eventIds: [String]
    public let type: String

    public init(eventIds: [String], type: String = "requires_action") {
        self.eventIds = eventIds
        self.type = type
    }
}

/// The turn ended because repeated errors exhausted the retry budget, or an error escalated to
/// `retryStatus: .terminal`. Ported from `beta_managed_agents_session_retries_exhausted.py`.
public struct BetaManagedAgentsSessionRetriesExhausted: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "retries_exhausted") {
        self.type = type
    }
}

/// The agent stopped because the session's tracked list cost reached its budget (or usage includes
/// a model with no list price, which the budget cannot measure). Ported from
/// `beta_managed_agents_session_budget_reached.py`.
public struct BetaManagedAgentsSessionBudgetReached: Codable, Sendable, Equatable {
    public let type: String

    public init(type: String = "budget_reached") {
        self.type = type
    }
}

/// Ported from the `StopReason` union shared verbatim by `session.status_idle` and
/// `session.thread_status_idle` (`beta_managed_agents_session_status_idle_event.py` and
/// `beta_managed_agents_session_thread_status_idle_event.py`).
public enum BetaManagedAgentsSessionStopReason: Sendable, Equatable {
    case endTurn(BetaManagedAgentsSessionEndTurn)
    case requiresAction(BetaManagedAgentsSessionRequiresAction)
    case retriesExhausted(BetaManagedAgentsSessionRetriesExhausted)
    case budgetReached(BetaManagedAgentsSessionBudgetReached)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionStopReason: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "end_turn": self = .endTurn(try BetaManagedAgentsSessionEndTurn(from: decoder))
        case "requires_action": self = .requiresAction(try BetaManagedAgentsSessionRequiresAction(from: decoder))
        case "retries_exhausted":
            self = .retriesExhausted(try BetaManagedAgentsSessionRetriesExhausted(from: decoder))
        case "budget_reached": self = .budgetReached(try BetaManagedAgentsSessionBudgetReached(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .endTurn(let value): try value.encode(to: encoder)
        case .requiresAction(let value): try value.encode(to: encoder)
        case .retriesExhausted(let value): try value.encode(to: encoder)
        case .budgetReached(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Token usage for a single model request. Ported from `beta_managed_agents_span_model_usage.py`.
/// **Not** the same shape as `BetaManagedAgentsSessionUsage` -- these token fields are
/// non-optional `Int`, and there is no `activeSeconds`/`listCost`/`serverToolUse`.
public struct BetaManagedAgentsSpanModelUsage: Codable, Sendable, Equatable {
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let speed: BetaManagedAgentsModelSpeed?

    public init(
        cacheCreationInputTokens: Int, cacheReadInputTokens: Int, inputTokens: Int, outputTokens: Int,
        speed: BetaManagedAgentsModelSpeed? = nil
    ) {
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.speed = speed
    }
}

/// Whether a tool call was auto-allowed, requires confirmation, or was denied. Ported from the
/// `evaluated_permission` literal field local to `agent.tool_use` and `agent.mcp_tool_use`.
public enum BetaManagedAgentsAgentEvaluatedPermission: Sendable, Equatable {
    case allow
    case ask
    case deny
    case unknown(String)
}

extension BetaManagedAgentsAgentEvaluatedPermission: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "allow": self = .allow
        case "ask": self = .ask
        case "deny": self = .deny
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .allow: try container.encode("allow")
        case .ask: try container.encode("ask")
        case .deny: try container.encode("deny")
        case .unknown(let value): try container.encode(value)
        }
    }
}

/// Whether the user allowed or denied a tool call that required confirmation. Ported from the
/// `result` literal field on `user.tool_confirmation` (event and params).
public enum BetaManagedAgentsUserToolConfirmationResult: Sendable, Equatable {
    case allow
    case deny
    case unknown(String)
}

extension BetaManagedAgentsUserToolConfirmationResult: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "allow": self = .allow
        case "deny": self = .deny
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .allow: try container.encode("allow")
        case .deny: try container.encode("deny")
        case .unknown(let value): try container.encode(value)
        }
    }
}

/// Regular text content, scoped to `system.message`. Ported from
/// `beta_managed_agents_system_content_block.py` (a nominally distinct, but field-identical, type
/// from `BetaManagedAgentsTextBlock`).
public struct BetaManagedAgentsSystemContentBlock: Codable, Sendable, Equatable {
    public let text: String
    public let type: String

    public init(text: String, type: String = "text") {
        self.text = text
        self.type = type
    }
}

/// Rubric referenced by a file uploaded via the Files API. Response-side mirror of
/// `BetaManagedAgentsFileRubricParams`. Ported from `beta_managed_agents_file_rubric.py`.
public struct BetaManagedAgentsFileRubric: Codable, Sendable, Equatable {
    public let fileId: String
    public let type: String

    public init(fileId: String, type: String = "file") {
        self.fileId = fileId
        self.type = type
    }
}

/// Rubric content provided inline as text. Response-side mirror of
/// `BetaManagedAgentsTextRubricParams`. Ported from `beta_managed_agents_text_rubric.py`.
public struct BetaManagedAgentsTextRubric: Codable, Sendable, Equatable {
    public let content: String
    public let type: String

    public init(content: String, type: String = "text") {
        self.content = content
        self.type = type
    }
}

/// Ported from the `Rubric` union local to `beta_managed_agents_user_define_outcome_event.py`.
public enum BetaManagedAgentsSessionRubric: Sendable, Equatable {
    case file(BetaManagedAgentsFileRubric)
    case text(BetaManagedAgentsTextRubric)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionRubric: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "file": self = .file(try BetaManagedAgentsFileRubric(from: decoder))
        case "text": self = .text(try BetaManagedAgentsTextRubric(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .file(let value): try value.encode(to: encoder)
        case .text(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
