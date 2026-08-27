import Anthropic

/// `user.*` and `system.message` session event leaf types. Ported from
/// `types/beta/sessions/beta_managed_agents_user_*.py`,
/// `types/beta/beta_managed_agents_user_tool_result_event.py`, and
/// `types/beta/beta_managed_agents_system_message_event.py`.

/// A message sent by the user (or synthesized on the user's behalf) into the session. Ported from
/// `beta_managed_agents_user_message_event.py`.
public struct BetaManagedAgentsUserMessageEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsSessionMessageContent]
    public let id: String
    public let type: String
    public let processedAt: String?

    public init(
        content: [BetaManagedAgentsSessionMessageContent], id: String, type: String = "user.message",
        processedAt: String? = nil
    ) {
        self.content = content
        self.id = id
        self.type = type
        self.processedAt = processedAt
    }
}

/// The user interrupted the currently running agent turn. Ported from
/// `beta_managed_agents_user_interrupt_event.py`.
public struct BetaManagedAgentsUserInterruptEvent: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let processedAt: String?
    public let sessionThreadId: String?

    public init(
        id: String, type: String = "user.interrupt", processedAt: String? = nil,
        sessionThreadId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
    }
}

/// The user's response to a tool call that required confirmation. Ported from
/// `beta_managed_agents_user_tool_confirmation_event.py`.
public struct BetaManagedAgentsUserToolConfirmationEvent: Codable, Sendable, Equatable {
    public let id: String
    public let result: BetaManagedAgentsUserToolConfirmationResult
    public let toolUseId: String
    public let type: String
    public let denyMessage: String?
    public let processedAt: String?
    public let sessionThreadId: String?

    public init(
        id: String, result: BetaManagedAgentsUserToolConfirmationResult, toolUseId: String,
        type: String = "user.tool_confirmation",
        denyMessage: String? = nil, processedAt: String? = nil, sessionThreadId: String? = nil
    ) {
        self.id = id
        self.result = result
        self.toolUseId = toolUseId
        self.type = type
        self.denyMessage = denyMessage
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
    }
}

/// The result of a client-executed custom tool call, supplied by the user. Ported from
/// `beta_managed_agents_user_custom_tool_result_event.py`.
public struct BetaManagedAgentsUserCustomToolResultEvent: Codable, Sendable, Equatable {
    public let customToolUseId: String
    public let id: String
    public let type: String
    public let content: [BetaManagedAgentsToolResultContent]?
    public let isError: Bool?
    public let processedAt: String?
    public let sessionThreadId: String?

    public init(
        customToolUseId: String, id: String, type: String = "user.custom_tool_result",
        content: [BetaManagedAgentsToolResultContent]? = nil, isError: Bool? = nil,
        processedAt: String? = nil, sessionThreadId: String? = nil
    ) {
        self.customToolUseId = customToolUseId
        self.id = id
        self.type = type
        self.content = content
        self.isError = isError
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
    }
}

/// The result of a server tool call, supplied by the user on the agent's behalf. Ported from
/// `types/beta/beta_managed_agents_user_tool_result_event.py` (root-level path in Python; no
/// bearing on Swift's organization).
public struct BetaManagedAgentsUserToolResultEvent: Codable, Sendable, Equatable {
    public let id: String
    public let toolUseId: String
    public let type: String
    public let content: [BetaManagedAgentsToolResultContent]?
    public let isError: Bool?
    public let processedAt: String?
    public let sessionThreadId: String?

    public init(
        id: String, toolUseId: String, type: String = "user.tool_result",
        content: [BetaManagedAgentsToolResultContent]? = nil, isError: Bool? = nil,
        processedAt: String? = nil, sessionThreadId: String? = nil
    ) {
        self.id = id
        self.toolUseId = toolUseId
        self.type = type
        self.content = content
        self.isError = isError
        self.processedAt = processedAt
        self.sessionThreadId = sessionThreadId
    }
}

/// The user defined a new outcome (a rubric-graded objective) for the session to pursue. Ported
/// from `beta_managed_agents_user_define_outcome_event.py`.
public struct BetaManagedAgentsUserDefineOutcomeEvent: Codable, Sendable, Equatable {
    public let description: String
    public let id: String
    public let outcomeId: String
    public let rubric: BetaManagedAgentsSessionRubric
    public let type: String
    public let maxIterations: Int?
    public let processedAt: String?

    public init(
        description: String, id: String, outcomeId: String, rubric: BetaManagedAgentsSessionRubric,
        type: String = "user.define_outcome", maxIterations: Int? = nil, processedAt: String? = nil
    ) {
        self.description = description
        self.id = id
        self.outcomeId = outcomeId
        self.rubric = rubric
        self.type = type
        self.maxIterations = maxIterations
        self.processedAt = processedAt
    }
}

/// A system-level message injected into the session (not attributable to the user or the agent).
/// Ported from `types/beta/beta_managed_agents_system_message_event.py` (root-level path in
/// Python).
public struct BetaManagedAgentsSystemMessageEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsSystemContentBlock]
    public let id: String
    public let type: String
    public let processedAt: String?

    public init(
        content: [BetaManagedAgentsSystemContentBlock], id: String, type: String = "system.message",
        processedAt: String? = nil
    ) {
        self.content = content
        self.id = id
        self.type = type
        self.processedAt = processedAt
    }
}
