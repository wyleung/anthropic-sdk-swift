import Anthropic

/// Rubric referenced by a file uploaded via the Files API. Ported from
/// `sessions/beta_managed_agents_file_rubric_params.py`.
public struct BetaManagedAgentsFileRubricParams: Encodable, Sendable, Equatable {
    public var fileId: String
    public var type = "file"

    public init(fileId: String) {
        self.fileId = fileId
    }
}

/// Rubric content provided inline as text. Ported from
/// `sessions/beta_managed_agents_text_rubric_params.py`.
public struct BetaManagedAgentsTextRubricParams: Encodable, Sendable, Equatable {
    public var content: String
    public var type = "text"

    public init(content: String) {
        self.content = content
    }
}

/// Ported from the `Rubric` union local to
/// `sessions/beta_managed_agents_user_define_outcome_event_params.py`. Request-only (no
/// `.unknown`); each leaf carries its own fixed `type` literal.
public enum BetaManagedAgentsRubricParam: Sendable, Equatable {
    case file(BetaManagedAgentsFileRubricParams)
    case text(BetaManagedAgentsTextRubricParams)
}

extension BetaManagedAgentsRubricParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .file(let value): try value.encode(to: encoder)
        case .text(let value): try value.encode(to: encoder)
        }
    }
}

/// Parameters for sending a user message to the session, as one of `SessionCreateParams`'s
/// `initialEvents`. Ported from `sessions/beta_managed_agents_user_message_event_params.py`.
public struct BetaManagedAgentsUserMessageEventParams: Encodable, Sendable, Equatable {
    public var content: [BetaManagedAgentsUserMessageContentParam]
    public var type = "user.message"

    public init(content: [BetaManagedAgentsUserMessageContentParam]) {
        self.content = content
    }
}

/// Parameters for defining an outcome the agent should work toward; the agent begins work on
/// receipt. Ported from `sessions/beta_managed_agents_user_define_outcome_event_params.py`.
public struct BetaManagedAgentsUserDefineOutcomeEventParams: Encodable, Sendable, Equatable {
    public var description: String
    public var rubric: BetaManagedAgentsRubricParam
    public var type = "user.define_outcome"
    public var maxIterations: Int?

    public init(description: String, rubric: BetaManagedAgentsRubricParam, maxIterations: Int? = nil) {
        self.description = description
        self.rubric = rubric
        self.maxIterations = maxIterations
    }
}

/// Ported from the `InitialEvent` union local to `session_create_params.py`. Request-only (no
/// `.unknown`); each leaf carries its own fixed `type` literal.
public enum BetaManagedAgentsInitialEventParam: Sendable, Equatable {
    case userMessage(BetaManagedAgentsUserMessageEventParams)
    case userDefineOutcome(BetaManagedAgentsUserDefineOutcomeEventParams)
}

extension BetaManagedAgentsInitialEventParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let value): try value.encode(to: encoder)
        case .userDefineOutcome(let value): try value.encode(to: encoder)
        }
    }
}
