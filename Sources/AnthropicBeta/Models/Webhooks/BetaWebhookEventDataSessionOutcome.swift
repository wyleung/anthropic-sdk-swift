import Anthropic

/// Mirrors `types/beta/beta_webhook_session_outcome_evaluation_ended_event_data.py`.
public struct BetaWebhookSessionOutcomeEvaluationEndedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let organizationId: String
    public let type: String
    public let workspaceId: String

    public init(
        id: String, organizationId: String, type: String = "session.outcome_evaluation_ended",
        workspaceId: String
    ) {
        self.id = id
        self.organizationId = organizationId
        self.type = type
        self.workspaceId = workspaceId
    }
}
