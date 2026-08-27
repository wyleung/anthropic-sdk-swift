import Anthropic

/// An asynchronous memory-consolidation job that reads a memory store plus a set of session
/// transcripts and writes consolidated memories into an output memory store -- a new store by
/// default, or an existing store chosen via `outputBehavior`. Ported from `beta_dream.py`.
///
/// The Dreams API is in research preview: the request and response shapes are volatile and may
/// change without the deprecation period that applies to generally-available endpoints.
public struct BetaDream: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let createdAt: String
    public let endedAt: String?
    public let error: BetaDreamError?
    public let inputs: [BetaDreamInput]
    public let instructions: String?
    public let model: BetaDreamModelConfig
    public let outputBehavior: BetaOutputBehavior
    public let outputs: [BetaDreamOutput]
    public let sessionId: String?
    public let status: BetaDreamStatus
    public let type: String
    public let usage: BetaDreamUsage

    public init(
        id: String,
        archivedAt: String? = nil,
        createdAt: String,
        endedAt: String? = nil,
        error: BetaDreamError? = nil,
        inputs: [BetaDreamInput],
        instructions: String? = nil,
        model: BetaDreamModelConfig,
        outputBehavior: BetaOutputBehavior,
        outputs: [BetaDreamOutput],
        sessionId: String? = nil,
        status: BetaDreamStatus,
        type: String = "dream",
        usage: BetaDreamUsage
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.error = error
        self.inputs = inputs
        self.instructions = instructions
        self.model = model
        self.outputBehavior = outputBehavior
        self.outputs = outputs
        self.sessionId = sessionId
        self.status = status
        self.type = type
        self.usage = usage
    }
}
