import Anthropic

/// Request-side params for `client.beta.sessions.events.send` and the response wrapper it returns.
/// Ported from `types/beta/sessions/beta_managed_agents_event_params.py`,
/// `beta_managed_agents_user_interrupt_event_params.py`,
/// `beta_managed_agents_user_tool_confirmation_event_params.py`,
/// `beta_managed_agents_user_custom_tool_result_event_params.py`,
/// `beta_managed_agents_user_tool_result_event_params.py`,
/// `beta_managed_agents_system_message_event_params.py`,
/// `beta_managed_agents_search_result_*_param.py`,
/// `types/beta/beta_managed_agents_system_content_block_param.py`, and
/// `beta_managed_agents_send_session_events.py`.

/// Citation settings for a search result. Ported from
/// `sessions/beta_managed_agents_search_result_citations_param.py`.
public struct BetaManagedAgentsSearchResultCitationsParam: Encodable, Sendable, Equatable {
    public var enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

/// Text content within a search result. Ported from
/// `sessions/beta_managed_agents_search_result_content_param.py`.
public struct BetaManagedAgentsSearchResultContentParam: Encodable, Sendable, Equatable {
    public var text: String
    public var type = "text"

    public init(text: String) {
        self.text = text
    }
}

/// A block containing a web search result. Ported from
/// `sessions/beta_managed_agents_search_result_block_param.py`.
public struct BetaManagedAgentsSearchResultBlockParam: Encodable, Sendable, Equatable {
    public var citations: BetaManagedAgentsSearchResultCitationsParam
    public var content: [BetaManagedAgentsSearchResultContentParam]
    public var source: String
    public var title: String
    public var type = "search_result"

    public init(
        citations: BetaManagedAgentsSearchResultCitationsParam,
        content: [BetaManagedAgentsSearchResultContentParam], source: String, title: String
    ) {
        self.citations = citations
        self.content = content
        self.source = source
        self.title = title
    }
}

/// Ported from the `Content` union local to both
/// `sessions/beta_managed_agents_user_custom_tool_result_event_params.py` and
/// `beta_managed_agents_user_tool_result_event_params.py` (byte-identical in both). Request-only
/// (no `.unknown`); each leaf carries its own fixed `type` literal.
public enum BetaManagedAgentsToolResultContentParam: Sendable, Equatable {
    case text(BetaManagedAgentsTextBlockParam)
    case image(BetaManagedAgentsImageBlockParam)
    case document(BetaManagedAgentsDocumentBlockParam)
    case searchResult(BetaManagedAgentsSearchResultBlockParam)
}

extension BetaManagedAgentsToolResultContentParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value): try value.encode(to: encoder)
        case .image(let value): try value.encode(to: encoder)
        case .document(let value): try value.encode(to: encoder)
        case .searchResult(let value): try value.encode(to: encoder)
        }
    }
}

/// Regular text content, scoped to `system.message` params. Ported from
/// `types/beta/beta_managed_agents_system_content_block_param.py` (root path in Python; a
/// nominally distinct, but field-identical, type from `BetaManagedAgentsTextBlockParam`).
public struct BetaManagedAgentsSystemContentBlockParam: Encodable, Sendable, Equatable {
    public var text: String
    public var type = "text"

    public init(text: String) {
        self.text = text
    }
}

/// Parameters for sending an interrupt to pause the agent. Ported from
/// `sessions/beta_managed_agents_user_interrupt_event_params.py`.
public struct BetaManagedAgentsUserInterruptEventParams: Encodable, Sendable, Equatable {
    public var type = "user.interrupt"
    public var sessionThreadId: String?

    public init(sessionThreadId: String? = nil) {
        self.sessionThreadId = sessionThreadId
    }
}

/// Parameters for confirming or denying a tool execution request. Ported from
/// `sessions/beta_managed_agents_user_tool_confirmation_event_params.py`.
public struct BetaManagedAgentsUserToolConfirmationEventParams: Encodable, Sendable, Equatable {
    public var result: BetaManagedAgentsUserToolConfirmationResult
    public var toolUseId: String
    public var type = "user.tool_confirmation"
    public var denyMessage: String?

    public init(
        result: BetaManagedAgentsUserToolConfirmationResult, toolUseId: String, denyMessage: String? = nil
    ) {
        self.result = result
        self.toolUseId = toolUseId
        self.denyMessage = denyMessage
    }
}

/// Parameters for providing the result of a custom tool execution. Ported from
/// `sessions/beta_managed_agents_user_custom_tool_result_event_params.py`.
public struct BetaManagedAgentsUserCustomToolResultEventParams: Encodable, Sendable, Equatable {
    public var customToolUseId: String
    public var type = "user.custom_tool_result"
    public var content: [BetaManagedAgentsToolResultContentParam]?
    public var isError: Bool?

    public init(
        customToolUseId: String, content: [BetaManagedAgentsToolResultContentParam]? = nil,
        isError: Bool? = nil
    ) {
        self.customToolUseId = customToolUseId
        self.content = content
        self.isError = isError
    }
}

/// Parameters for providing the result of an agent-toolset tool execution. Only valid on
/// `self_hosted` environments, where sandbox-routed tools are executed by the client rather than
/// the server. Ported from `beta_managed_agents_user_tool_result_event_params.py`.
public struct BetaManagedAgentsUserToolResultEventParams: Encodable, Sendable, Equatable {
    public var toolUseId: String
    public var type = "user.tool_result"
    public var content: [BetaManagedAgentsToolResultContentParam]?
    public var isError: Bool?

    public init(
        toolUseId: String, content: [BetaManagedAgentsToolResultContentParam]? = nil, isError: Bool? = nil
    ) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Privileged context for the accompanying turn and all subsequent turns, appended to the
/// session's system context as a `role: "system"` turn rather than replacing the top-level system
/// prompt. At most one per request: it must be the final event and immediately follow the
/// `user.message`, `user.tool_result`, or `user.custom_tool_result` it accompanies. Only supported
/// on models that accept mid-conversation system messages. Ported from
/// `sessions/beta_managed_agents_system_message_event_params.py`.
public struct BetaManagedAgentsSystemMessageEventParams: Encodable, Sendable, Equatable {
    public var content: [BetaManagedAgentsSystemContentBlockParam]
    public var type = "system.message"

    public init(content: [BetaManagedAgentsSystemContentBlockParam]) {
        self.content = content
    }
}

/// Ported from `sessions/beta_managed_agents_event_params.py`'s `BetaManagedAgentsEventParams`
/// union, the payload accepted by `events.send`. Request-only (no `.unknown`); each leaf carries
/// its own fixed `type` literal. Reuses `BetaManagedAgentsUserMessageEventParams` and
/// `BetaManagedAgentsUserDefineOutcomeEventParams` from `BetaManagedAgentsSessionInitialEventParams.swift`.
public enum BetaManagedAgentsEventParams: Sendable, Equatable {
    case userMessage(BetaManagedAgentsUserMessageEventParams)
    case userInterrupt(BetaManagedAgentsUserInterruptEventParams)
    case userToolConfirmation(BetaManagedAgentsUserToolConfirmationEventParams)
    case userCustomToolResult(BetaManagedAgentsUserCustomToolResultEventParams)
    case userDefineOutcome(BetaManagedAgentsUserDefineOutcomeEventParams)
    case userToolResult(BetaManagedAgentsUserToolResultEventParams)
    case systemMessage(BetaManagedAgentsSystemMessageEventParams)
}

extension BetaManagedAgentsEventParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let value): try value.encode(to: encoder)
        case .userInterrupt(let value): try value.encode(to: encoder)
        case .userToolConfirmation(let value): try value.encode(to: encoder)
        case .userCustomToolResult(let value): try value.encode(to: encoder)
        case .userDefineOutcome(let value): try value.encode(to: encoder)
        case .userToolResult(let value): try value.encode(to: encoder)
        case .systemMessage(let value): try value.encode(to: encoder)
        }
    }
}

/// Ported from the `Data` union local to `beta_managed_agents_send_session_events.py`. Response-side
/// echo of the events that were successfully sent; reuses 7 of the 35 leaf event structs from
/// `BetaManagedAgentsSessionEvent`.
public enum BetaManagedAgentsSendSessionEventsData: Sendable, Equatable {
    case userMessage(BetaManagedAgentsUserMessageEvent)
    case userInterrupt(BetaManagedAgentsUserInterruptEvent)
    case userToolConfirmation(BetaManagedAgentsUserToolConfirmationEvent)
    case userCustomToolResult(BetaManagedAgentsUserCustomToolResultEvent)
    case userDefineOutcome(BetaManagedAgentsUserDefineOutcomeEvent)
    case userToolResult(BetaManagedAgentsUserToolResultEvent)
    case systemMessage(BetaManagedAgentsSystemMessageEvent)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSendSessionEventsData: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "user.message": self = .userMessage(try BetaManagedAgentsUserMessageEvent(from: decoder))
        case "user.interrupt": self = .userInterrupt(try BetaManagedAgentsUserInterruptEvent(from: decoder))
        case "user.tool_confirmation":
            self = .userToolConfirmation(try BetaManagedAgentsUserToolConfirmationEvent(from: decoder))
        case "user.custom_tool_result":
            self = .userCustomToolResult(try BetaManagedAgentsUserCustomToolResultEvent(from: decoder))
        case "user.define_outcome":
            self = .userDefineOutcome(try BetaManagedAgentsUserDefineOutcomeEvent(from: decoder))
        case "user.tool_result": self = .userToolResult(try BetaManagedAgentsUserToolResultEvent(from: decoder))
        case "system.message": self = .systemMessage(try BetaManagedAgentsSystemMessageEvent(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let value): try value.encode(to: encoder)
        case .userInterrupt(let value): try value.encode(to: encoder)
        case .userToolConfirmation(let value): try value.encode(to: encoder)
        case .userCustomToolResult(let value): try value.encode(to: encoder)
        case .userDefineOutcome(let value): try value.encode(to: encoder)
        case .userToolResult(let value): try value.encode(to: encoder)
        case .systemMessage(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Events that were successfully sent to the session. Ported from
/// `beta_managed_agents_send_session_events.py`.
public struct BetaManagedAgentsSendSessionEvents: Codable, Sendable, Equatable {
    public let data: [BetaManagedAgentsSendSessionEventsData]?

    public init(data: [BetaManagedAgentsSendSessionEventsData]? = nil) {
        self.data = data
    }
}
