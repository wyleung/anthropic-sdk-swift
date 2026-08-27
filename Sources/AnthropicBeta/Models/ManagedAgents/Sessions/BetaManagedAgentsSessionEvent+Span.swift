import Anthropic

/// `span.*` session event leaf types. Ported from
/// `types/beta/sessions/beta_managed_agents_span_*.py`. These events bracket a unit of work (an
/// outcome evaluation, a model request) with a start/end pair sharing a correlating id.

/// An outcome evaluation (grading the session's progress against a rubric) started. Ported from
/// `beta_managed_agents_span_outcome_evaluation_start_event.py`.
public struct BetaManagedAgentsSpanOutcomeEvaluationStartEvent: Codable, Sendable, Equatable {
    public let id: String
    public let iteration: Int
    public let outcomeId: String
    public let processedAt: String
    public let type: String

    public init(
        id: String, iteration: Int, outcomeId: String, processedAt: String,
        type: String = "span.outcome_evaluation_start"
    ) {
        self.id = id
        self.iteration = iteration
        self.outcomeId = outcomeId
        self.processedAt = processedAt
        self.type = type
    }
}

/// An outcome evaluation is still in progress (emitted for long-running evaluations). Ported from
/// `beta_managed_agents_span_outcome_evaluation_ongoing_event.py`.
public struct BetaManagedAgentsSpanOutcomeEvaluationOngoingEvent: Codable, Sendable, Equatable {
    public let id: String
    public let iteration: Int
    public let outcomeId: String
    public let processedAt: String
    public let type: String

    public init(
        id: String, iteration: Int, outcomeId: String, processedAt: String,
        type: String = "span.outcome_evaluation_ongoing"
    ) {
        self.id = id
        self.iteration = iteration
        self.outcomeId = outcomeId
        self.processedAt = processedAt
        self.type = type
    }
}

/// An outcome evaluation finished. `result` is intentionally a plain `String` (matching Python's
/// `str` field type) rather than a closed enum, even though the API documents a fixed set of
/// values (`satisfied`, `needs_revision`, `max_iterations_reached`, `failed`, `interrupted`).
/// Ported from `beta_managed_agents_span_outcome_evaluation_end_event.py`.
public struct BetaManagedAgentsSpanOutcomeEvaluationEndEvent: Codable, Sendable, Equatable {
    public let explanation: String
    public let id: String
    public let iteration: Int
    public let outcomeEvaluationStartId: String
    public let outcomeId: String
    public let processedAt: String
    public let result: String
    public let type: String
    public let usage: BetaManagedAgentsSpanModelUsage

    public init(
        explanation: String, id: String, iteration: Int, outcomeEvaluationStartId: String,
        outcomeId: String, processedAt: String, result: String, type: String = "span.outcome_evaluation_end",
        usage: BetaManagedAgentsSpanModelUsage
    ) {
        self.explanation = explanation
        self.id = id
        self.iteration = iteration
        self.outcomeEvaluationStartId = outcomeEvaluationStartId
        self.outcomeId = outcomeId
        self.processedAt = processedAt
        self.result = result
        self.type = type
        self.usage = usage
    }
}

/// A model request started. Ported from `beta_managed_agents_span_model_request_start_event.py`.
public struct BetaManagedAgentsSpanModelRequestStartEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String

    public init(id: String, processedAt: String, type: String = "span.model_request_start") {
        self.id = id
        self.processedAt = processedAt
        self.type = type
    }
}

/// A model request finished. Ported from `beta_managed_agents_span_model_request_end_event.py`.
public struct BetaManagedAgentsSpanModelRequestEndEvent: Codable, Sendable, Equatable {
    public let id: String
    public let modelRequestStartId: String
    public let modelUsage: BetaManagedAgentsSpanModelUsage
    public let processedAt: String
    public let type: String
    public let isError: Bool?

    public init(
        id: String, modelRequestStartId: String, modelUsage: BetaManagedAgentsSpanModelUsage,
        processedAt: String, type: String = "span.model_request_end", isError: Bool? = nil
    ) {
        self.id = id
        self.modelRequestStartId = modelRequestStartId
        self.modelUsage = modelUsage
        self.processedAt = processedAt
        self.type = type
        self.isError = isError
    }
}
