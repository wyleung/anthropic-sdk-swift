import Anthropic

/// A user message sent to each session created from a deployment. Ported from
/// `beta_managed_agents_deployment_user_message_event.py`. Reuses `BetaManagedAgentsSessionMessageContent`
/// (`BetaManagedAgentsSessionEventContent.swift`) for its `content` union, the same one Session
/// events already use.
public struct BetaManagedAgentsDeploymentUserMessageEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsSessionMessageContent]
    public let type: String

    public init(content: [BetaManagedAgentsSessionMessageContent], type: String = "user.message") {
        self.content = content
        self.type = type
    }
}

/// An outcome the agent should work toward, sent to each session created from a deployment; the
/// agent begins work on receipt. Ported from
/// `beta_managed_agents_deployment_user_define_outcome_event.py`. Reuses `BetaManagedAgentsSessionRubric`
/// (`BetaManagedAgentsSessionEventSupportTypes.swift`).
public struct BetaManagedAgentsDeploymentUserDefineOutcomeEvent: Codable, Sendable, Equatable {
    public let description: String
    public let rubric: BetaManagedAgentsSessionRubric
    public let type: String
    public let maxIterations: Int?

    public init(
        description: String,
        rubric: BetaManagedAgentsSessionRubric,
        type: String = "user.define_outcome",
        maxIterations: Int? = nil
    ) {
        self.description = description
        self.rubric = rubric
        self.type = type
        self.maxIterations = maxIterations
    }
}

/// Privileged context sent to each session created from a deployment, appended to the session's
/// system context as a `role: "system"` turn rather than replacing the top-level system prompt.
/// Ported from `beta_managed_agents_deployment_system_message_event.py`. Reuses
/// `BetaManagedAgentsSystemContentBlock` (`BetaManagedAgentsSessionEventSupportTypes.swift`).
public struct BetaManagedAgentsDeploymentSystemMessageEvent: Codable, Sendable, Equatable {
    public let content: [BetaManagedAgentsSystemContentBlock]
    public let type: String

    public init(content: [BetaManagedAgentsSystemContentBlock], type: String = "system.message") {
        self.content = content
        self.type = type
    }
}

/// Ported from `beta_managed_agents_deployment_initial_event.py` --
/// `Union[BetaManagedAgentsDeploymentUserMessageEvent, BetaManagedAgentsDeploymentUserDefineOutcomeEvent, BetaManagedAgentsDeploymentSystemMessageEvent]`,
/// discriminated on `type`. Distinct from the session-side `BetaManagedAgentsInitialEventParam`
/// (only 2 cases, request-only) -- this is the 3-case response-side union.
public enum BetaManagedAgentsDeploymentInitialEvent: Sendable, Equatable {
    case userMessage(BetaManagedAgentsDeploymentUserMessageEvent)
    case userDefineOutcome(BetaManagedAgentsDeploymentUserDefineOutcomeEvent)
    case systemMessage(BetaManagedAgentsDeploymentSystemMessageEvent)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsDeploymentInitialEvent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "user.message":
            self = .userMessage(try BetaManagedAgentsDeploymentUserMessageEvent(from: decoder))
        case "user.define_outcome":
            self = .userDefineOutcome(try BetaManagedAgentsDeploymentUserDefineOutcomeEvent(from: decoder))
        case "system.message":
            self = .systemMessage(try BetaManagedAgentsDeploymentSystemMessageEvent(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let value): try value.encode(to: encoder)
        case .userDefineOutcome(let value): try value.encode(to: encoder)
        case .systemMessage(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
