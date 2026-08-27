import Anthropic

/// Stream-only wrapper types and the top-level streaming event union. `event_start`/`event_delta`
/// only ever appear on the SSE stream (never in the persisted event log returned by `list`), which
/// is why they live in their own file alongside `BetaManagedAgentsStreamSessionEvents` rather than
/// in `BetaManagedAgentsSessionEvent.swift`. Ported from the root-level
/// `types/beta/beta_managed_agents_start_event*.py`, `beta_managed_agents_delta_*.py`, and
/// `types/beta/sessions/beta_managed_agents_stream_session_events.py`.

/// A preview announcing that the agent is about to produce a text message, before any content
/// arrives. Ported from `beta_managed_agents_agent_message_preview.py`.
public struct BetaManagedAgentsAgentMessagePreview: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "agent.message") {
        self.id = id
        self.type = type
    }
}

/// A preview announcing that the agent is about to produce a thinking step, before any content
/// arrives. Ported from `beta_managed_agents_agent_thinking_preview.py`.
public struct BetaManagedAgentsAgentThinkingPreview: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "agent.thinking") {
        self.id = id
        self.type = type
    }
}

/// Ported from the `Preview` union local to `beta_managed_agents_start_event_preview.py`.
public enum BetaManagedAgentsStartEventPreview: Sendable, Equatable {
    case agentMessage(BetaManagedAgentsAgentMessagePreview)
    case agentThinking(BetaManagedAgentsAgentThinkingPreview)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsStartEventPreview: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "agent.message": self = .agentMessage(try BetaManagedAgentsAgentMessagePreview(from: decoder))
        case "agent.thinking": self = .agentThinking(try BetaManagedAgentsAgentThinkingPreview(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agentMessage(let value): try value.encode(to: encoder)
        case .agentThinking(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Announces the start of a new streamed event (a message or thinking step) before its content
/// begins arriving via `event_delta`. Ported from `beta_managed_agents_start_event.py`.
public struct BetaManagedAgentsStartEvent: Codable, Sendable, Equatable {
    public let event: BetaManagedAgentsStartEventPreview
    public let type: String

    public init(event: BetaManagedAgentsStartEventPreview, type: String = "event_start") {
        self.event = event
        self.type = type
    }
}

/// An incremental chunk of text content for an event previously announced via `event_start`.
/// Ported from `beta_managed_agents_delta_content.py`.
public struct BetaManagedAgentsDeltaContent: Codable, Sendable, Equatable {
    public let content: BetaManagedAgentsTextBlock
    public let type: String
    public let index: Int?

    public init(content: BetaManagedAgentsTextBlock, type: String = "content_delta", index: Int? = nil) {
        self.content = content
        self.type = type
        self.index = index
    }
}

/// Wraps an incremental content delta together with the id of the event it belongs to. Ported from
/// `beta_managed_agents_delta_event.py`.
public struct BetaManagedAgentsDeltaEvent: Codable, Sendable, Equatable {
    public let delta: BetaManagedAgentsDeltaContent
    public let eventId: String
    public let type: String

    public init(delta: BetaManagedAgentsDeltaContent, eventId: String, type: String = "event_delta") {
        self.delta = delta
        self.eventId = eventId
        self.type = type
    }
}

/// A single event on the session's SSE stream: every case from `BetaManagedAgentsSessionEvent`,
/// plus the two stream-only preview/delta wrapper events. Ported from the 37-member `Data` union in
/// `types/beta/sessions/beta_managed_agents_stream_session_events.py`. Member order matches the
/// Python union exactly -- identical to `BetaManagedAgentsSessionEvent`'s 35 members, except
/// `StartEvent` and `DeltaEvent` are inserted between `SessionUpdatedEvent` and `SystemMessageEvent`.
public enum BetaManagedAgentsStreamSessionEvents: Sendable, Equatable {
    case userMessage(BetaManagedAgentsUserMessageEvent)
    case userInterrupt(BetaManagedAgentsUserInterruptEvent)
    case userToolConfirmation(BetaManagedAgentsUserToolConfirmationEvent)
    case userCustomToolResult(BetaManagedAgentsUserCustomToolResultEvent)
    case agentCustomToolUse(BetaManagedAgentsAgentCustomToolUseEvent)
    case agentMessage(BetaManagedAgentsAgentMessageEvent)
    case agentThinking(BetaManagedAgentsAgentThinkingEvent)
    case agentMCPToolUse(BetaManagedAgentsAgentMCPToolUseEvent)
    case agentMCPToolResult(BetaManagedAgentsAgentMCPToolResultEvent)
    case agentToolUse(BetaManagedAgentsAgentToolUseEvent)
    case agentToolResult(BetaManagedAgentsAgentToolResultEvent)
    case agentThreadMessageReceived(BetaManagedAgentsAgentThreadMessageReceivedEvent)
    case agentThreadMessageSent(BetaManagedAgentsAgentThreadMessageSentEvent)
    case agentThreadContextCompacted(BetaManagedAgentsAgentThreadContextCompactedEvent)
    case sessionError(BetaManagedAgentsSessionErrorEvent)
    case sessionStatusRescheduled(BetaManagedAgentsSessionStatusRescheduledEvent)
    case sessionStatusRunning(BetaManagedAgentsSessionStatusRunningEvent)
    case sessionStatusIdle(BetaManagedAgentsSessionStatusIdleEvent)
    case sessionStatusTerminated(BetaManagedAgentsSessionStatusTerminatedEvent)
    case sessionThreadCreated(BetaManagedAgentsSessionThreadCreatedEvent)
    case spanOutcomeEvaluationStart(BetaManagedAgentsSpanOutcomeEvaluationStartEvent)
    case spanOutcomeEvaluationEnd(BetaManagedAgentsSpanOutcomeEvaluationEndEvent)
    case spanModelRequestStart(BetaManagedAgentsSpanModelRequestStartEvent)
    case spanModelRequestEnd(BetaManagedAgentsSpanModelRequestEndEvent)
    case spanOutcomeEvaluationOngoing(BetaManagedAgentsSpanOutcomeEvaluationOngoingEvent)
    case userDefineOutcome(BetaManagedAgentsUserDefineOutcomeEvent)
    case sessionDeleted(BetaManagedAgentsSessionDeletedEvent)
    case sessionThreadStatusRunning(BetaManagedAgentsSessionThreadStatusRunningEvent)
    case sessionThreadStatusIdle(BetaManagedAgentsSessionThreadStatusIdleEvent)
    case sessionThreadStatusTerminated(BetaManagedAgentsSessionThreadStatusTerminatedEvent)
    case userToolResult(BetaManagedAgentsUserToolResultEvent)
    case sessionThreadStatusRescheduled(BetaManagedAgentsSessionThreadStatusRescheduledEvent)
    case sessionUpdated(BetaManagedAgentsSessionUpdatedEvent)
    case startEvent(BetaManagedAgentsStartEvent)
    case deltaEvent(BetaManagedAgentsDeltaEvent)
    case systemMessage(BetaManagedAgentsSystemMessageEvent)
    case sessionUsage(BetaManagedAgentsSessionUsageEvent)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsStreamSessionEvents: Codable {
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
        case "agent.custom_tool_use":
            self = .agentCustomToolUse(try BetaManagedAgentsAgentCustomToolUseEvent(from: decoder))
        case "agent.message": self = .agentMessage(try BetaManagedAgentsAgentMessageEvent(from: decoder))
        case "agent.thinking": self = .agentThinking(try BetaManagedAgentsAgentThinkingEvent(from: decoder))
        case "agent.mcp_tool_use":
            self = .agentMCPToolUse(try BetaManagedAgentsAgentMCPToolUseEvent(from: decoder))
        case "agent.mcp_tool_result":
            self = .agentMCPToolResult(try BetaManagedAgentsAgentMCPToolResultEvent(from: decoder))
        case "agent.tool_use": self = .agentToolUse(try BetaManagedAgentsAgentToolUseEvent(from: decoder))
        case "agent.tool_result":
            self = .agentToolResult(try BetaManagedAgentsAgentToolResultEvent(from: decoder))
        case "agent.thread_message_received":
            self = .agentThreadMessageReceived(
                try BetaManagedAgentsAgentThreadMessageReceivedEvent(from: decoder))
        case "agent.thread_message_sent":
            self = .agentThreadMessageSent(try BetaManagedAgentsAgentThreadMessageSentEvent(from: decoder))
        case "agent.thread_context_compacted":
            self = .agentThreadContextCompacted(
                try BetaManagedAgentsAgentThreadContextCompactedEvent(from: decoder))
        case "session.error": self = .sessionError(try BetaManagedAgentsSessionErrorEvent(from: decoder))
        case "session.status_rescheduled":
            self = .sessionStatusRescheduled(
                try BetaManagedAgentsSessionStatusRescheduledEvent(from: decoder))
        case "session.status_running":
            self = .sessionStatusRunning(try BetaManagedAgentsSessionStatusRunningEvent(from: decoder))
        case "session.status_idle":
            self = .sessionStatusIdle(try BetaManagedAgentsSessionStatusIdleEvent(from: decoder))
        case "session.status_terminated":
            self = .sessionStatusTerminated(try BetaManagedAgentsSessionStatusTerminatedEvent(from: decoder))
        case "session.thread_created":
            self = .sessionThreadCreated(try BetaManagedAgentsSessionThreadCreatedEvent(from: decoder))
        case "span.outcome_evaluation_start":
            self = .spanOutcomeEvaluationStart(
                try BetaManagedAgentsSpanOutcomeEvaluationStartEvent(from: decoder))
        case "span.outcome_evaluation_end":
            self = .spanOutcomeEvaluationEnd(
                try BetaManagedAgentsSpanOutcomeEvaluationEndEvent(from: decoder))
        case "span.model_request_start":
            self = .spanModelRequestStart(try BetaManagedAgentsSpanModelRequestStartEvent(from: decoder))
        case "span.model_request_end":
            self = .spanModelRequestEnd(try BetaManagedAgentsSpanModelRequestEndEvent(from: decoder))
        case "span.outcome_evaluation_ongoing":
            self = .spanOutcomeEvaluationOngoing(
                try BetaManagedAgentsSpanOutcomeEvaluationOngoingEvent(from: decoder))
        case "user.define_outcome":
            self = .userDefineOutcome(try BetaManagedAgentsUserDefineOutcomeEvent(from: decoder))
        case "session.deleted": self = .sessionDeleted(try BetaManagedAgentsSessionDeletedEvent(from: decoder))
        case "session.thread_status_running":
            self = .sessionThreadStatusRunning(
                try BetaManagedAgentsSessionThreadStatusRunningEvent(from: decoder))
        case "session.thread_status_idle":
            self = .sessionThreadStatusIdle(try BetaManagedAgentsSessionThreadStatusIdleEvent(from: decoder))
        case "session.thread_status_terminated":
            self = .sessionThreadStatusTerminated(
                try BetaManagedAgentsSessionThreadStatusTerminatedEvent(from: decoder))
        case "user.tool_result": self = .userToolResult(try BetaManagedAgentsUserToolResultEvent(from: decoder))
        case "session.thread_status_rescheduled":
            self = .sessionThreadStatusRescheduled(
                try BetaManagedAgentsSessionThreadStatusRescheduledEvent(from: decoder))
        case "session.updated": self = .sessionUpdated(try BetaManagedAgentsSessionUpdatedEvent(from: decoder))
        case "event_start": self = .startEvent(try BetaManagedAgentsStartEvent(from: decoder))
        case "event_delta": self = .deltaEvent(try BetaManagedAgentsDeltaEvent(from: decoder))
        case "system.message": self = .systemMessage(try BetaManagedAgentsSystemMessageEvent(from: decoder))
        case "session.usage": self = .sessionUsage(try BetaManagedAgentsSessionUsageEvent(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let value): try value.encode(to: encoder)
        case .userInterrupt(let value): try value.encode(to: encoder)
        case .userToolConfirmation(let value): try value.encode(to: encoder)
        case .userCustomToolResult(let value): try value.encode(to: encoder)
        case .agentCustomToolUse(let value): try value.encode(to: encoder)
        case .agentMessage(let value): try value.encode(to: encoder)
        case .agentThinking(let value): try value.encode(to: encoder)
        case .agentMCPToolUse(let value): try value.encode(to: encoder)
        case .agentMCPToolResult(let value): try value.encode(to: encoder)
        case .agentToolUse(let value): try value.encode(to: encoder)
        case .agentToolResult(let value): try value.encode(to: encoder)
        case .agentThreadMessageReceived(let value): try value.encode(to: encoder)
        case .agentThreadMessageSent(let value): try value.encode(to: encoder)
        case .agentThreadContextCompacted(let value): try value.encode(to: encoder)
        case .sessionError(let value): try value.encode(to: encoder)
        case .sessionStatusRescheduled(let value): try value.encode(to: encoder)
        case .sessionStatusRunning(let value): try value.encode(to: encoder)
        case .sessionStatusIdle(let value): try value.encode(to: encoder)
        case .sessionStatusTerminated(let value): try value.encode(to: encoder)
        case .sessionThreadCreated(let value): try value.encode(to: encoder)
        case .spanOutcomeEvaluationStart(let value): try value.encode(to: encoder)
        case .spanOutcomeEvaluationEnd(let value): try value.encode(to: encoder)
        case .spanModelRequestStart(let value): try value.encode(to: encoder)
        case .spanModelRequestEnd(let value): try value.encode(to: encoder)
        case .spanOutcomeEvaluationOngoing(let value): try value.encode(to: encoder)
        case .userDefineOutcome(let value): try value.encode(to: encoder)
        case .sessionDeleted(let value): try value.encode(to: encoder)
        case .sessionThreadStatusRunning(let value): try value.encode(to: encoder)
        case .sessionThreadStatusIdle(let value): try value.encode(to: encoder)
        case .sessionThreadStatusTerminated(let value): try value.encode(to: encoder)
        case .userToolResult(let value): try value.encode(to: encoder)
        case .sessionThreadStatusRescheduled(let value): try value.encode(to: encoder)
        case .sessionUpdated(let value): try value.encode(to: encoder)
        case .startEvent(let value): try value.encode(to: encoder)
        case .deltaEvent(let value): try value.encode(to: encoder)
        case .systemMessage(let value): try value.encode(to: encoder)
        case .sessionUsage(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
