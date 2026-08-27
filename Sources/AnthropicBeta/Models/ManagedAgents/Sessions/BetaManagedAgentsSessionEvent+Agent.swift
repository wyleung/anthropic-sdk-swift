import Anthropic

/// `agent.*` session event leaf types. Ported from
/// `types/beta/sessions/beta_managed_agents_agent_*.py`.

/// Text produced by the agent as part of its response. Ported from
/// `beta_managed_agents_agent_message_event.py`.
public struct BetaManagedAgentsAgentMessageEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsAgentMessageContent]
    public let id: String
    public let processedAt: String
    public let type: String

    public init(
        content: [BetaManagedAgentsAgentMessageContent], id: String, processedAt: String,
        type: String = "agent.message"
    ) {
        self.content = content
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// The agent produced an internal reasoning step. Ported from
/// `beta_managed_agents_agent_thinking_event.py`.
public struct BetaManagedAgentsAgentThinkingEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "agent.thinking") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// The agent invoked a tool it manages directly (as opposed to an MCP or client-executed custom
/// tool). Ported from `beta_managed_agents_agent_tool_use_event.py`.
public struct BetaManagedAgentsAgentToolUseEvent: Codable, Sendable, Equatable {
    public let id: String
    public let input: [String: JSONValue]
    public let name: String
    public let processedAt: String
    public let type: String
    public let evaluatedPermission: BetaManagedAgentsAgentEvaluatedPermission?
    public let sessionThreadId: String?

    public init(
        id: String, input: [String: JSONValue], name: String, processedAt: String,
        type: String = "agent.tool_use",
        evaluatedPermission: BetaManagedAgentsAgentEvaluatedPermission? = nil,
        sessionThreadId: String? = nil
    ) {
        self.id = id
        self.input = input
        self.name = name
        self.processedAt = processedAt
        self.type = type
        self.evaluatedPermission = evaluatedPermission
        self.sessionThreadId = sessionThreadId
    }
}

/// The result of an agent-managed tool call. Ported from
/// `beta_managed_agents_agent_tool_result_event.py`.
public struct BetaManagedAgentsAgentToolResultEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let toolUseId: String
    public let type: String
    public let content: [BetaManagedAgentsToolResultContent]?
    public let isError: Bool?

    public init(
        id: String, processedAt: String, toolUseId: String, type: String = "agent.tool_result",
        content: [BetaManagedAgentsToolResultContent]? = nil, isError: Bool? = nil
    ) {
        self.id = id
        self.processedAt = processedAt
        self.toolUseId = toolUseId
        self.type = type
        self.content = content
        self.isError = isError
    }
}

/// The agent invoked a tool exposed by an MCP server. Ported from
/// `beta_managed_agents_agent_mcp_tool_use_event.py`.
public struct BetaManagedAgentsAgentMCPToolUseEvent: Codable, Sendable, Equatable {
    public let id: String
    public let input: [String: JSONValue]
    public let mcpServerName: String
    public let name: String
    public let processedAt: String
    public let type: String
    public let evaluatedPermission: BetaManagedAgentsAgentEvaluatedPermission?
    public let sessionThreadId: String?

    public init(
        id: String, input: [String: JSONValue], mcpServerName: String, name: String, processedAt: String,
        type: String = "agent.mcp_tool_use",
        evaluatedPermission: BetaManagedAgentsAgentEvaluatedPermission? = nil,
        sessionThreadId: String? = nil
    ) {
        self.id = id
        self.input = input
        self.mcpServerName = mcpServerName
        self.name = name
        self.processedAt = processedAt
        self.type = type
        self.evaluatedPermission = evaluatedPermission
        self.sessionThreadId = sessionThreadId
    }
}

/// The result of an MCP tool call. Ported from
/// `beta_managed_agents_agent_mcp_tool_result_event.py`.
public struct BetaManagedAgentsAgentMCPToolResultEvent: Codable, Sendable, Equatable {
    public let id: String
    public let mcpToolUseId: String
    public let processedAt: String
    public let type: String
    public let content: [BetaManagedAgentsToolResultContent]?
    public let isError: Bool?

    public init(
        id: String, mcpToolUseId: String, processedAt: String, type: String = "agent.mcp_tool_result",
        content: [BetaManagedAgentsToolResultContent]? = nil, isError: Bool? = nil
    ) {
        self.id = id
        self.mcpToolUseId = mcpToolUseId
        self.processedAt = processedAt
        self.type = type
        self.content = content
        self.isError = isError
    }
}

/// The agent invoked a client-executed custom tool; the client must supply the result via
/// `user.custom_tool_result`. Ported from `beta_managed_agents_agent_custom_tool_use_event.py`.
/// Unlike the two tool-use events above, this has no `evaluated_permission` field -- custom tools
/// are always client-executed, so there is no server-side permission to evaluate.
public struct BetaManagedAgentsAgentCustomToolUseEvent: Codable, Sendable, Equatable {
    public let id: String
    public let input: [String: JSONValue]
    public let name: String
    public let processedAt: String
    public let type: String
    public let sessionThreadId: String?

    public init(
        id: String, input: [String: JSONValue], name: String, processedAt: String,
        type: String = "agent.custom_tool_use", sessionThreadId: String? = nil
    ) {
        self.id = id
        self.input = input
        self.name = name
        self.processedAt = processedAt
        self.type = type
        self.sessionThreadId = sessionThreadId
    }
}

/// A message was received from another session thread (e.g. a sub-agent reporting back to its
/// parent). Ported from `beta_managed_agents_agent_thread_message_received_event.py`.
public struct BetaManagedAgentsAgentThreadMessageReceivedEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsSessionMessageContent]
    public let fromSessionThreadId: String
    public let id: String
    public let processedAt: String
    public let type: String
    public let fromAgentName: String?

    public init(
        content: [BetaManagedAgentsSessionMessageContent], fromSessionThreadId: String, id: String,
        processedAt: String, type: String = "agent.thread_message_received", fromAgentName: String? = nil
    ) {
        self.content = content
        self.fromSessionThreadId = fromSessionThreadId
        self.id = id
        self.processedAt = processedAt
        self.type = type
        self.fromAgentName = fromAgentName
    }
}

/// A message was sent to another session thread (e.g. delegating a sub-task to a spawned agent).
/// Ported from `beta_managed_agents_agent_thread_message_sent_event.py`.
public struct BetaManagedAgentsAgentThreadMessageSentEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsSessionMessageContent]
    public let id: String
    public let processedAt: String
    public let toSessionThreadId: String
    public let type: String
    public let toAgentName: String?

    public init(
        content: [BetaManagedAgentsSessionMessageContent], id: String, processedAt: String,
        toSessionThreadId: String, type: String = "agent.thread_message_sent", toAgentName: String? = nil
    ) {
        self.content = content
        self.id = id
        self.processedAt = processedAt
        self.toSessionThreadId = toSessionThreadId
        self.type = type
        self.toAgentName = toAgentName
    }
}

/// The agent's context window for a thread was compacted (summarized to free up space). Ported
/// from `beta_managed_agents_agent_thread_context_compacted_event.py`.
public struct BetaManagedAgentsAgentThreadContextCompactedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "agent.thread_context_compacted") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}
