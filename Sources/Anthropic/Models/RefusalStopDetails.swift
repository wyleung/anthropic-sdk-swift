public enum RefusalCategory: String, Codable, Sendable, Equatable {
    case cyber
    case bio
    case frontierLlm = "frontier_llm"
    case reasoningExtraction = "reasoning_extraction"
    case generalHarms = "general_harms"
}

public struct RefusalStopDetails: Codable, Sendable, Equatable {
    public let type = "refusal"
    public let category: RefusalCategory?
    public let explanation: String?

    private enum CodingKeys: String, CodingKey {
        case type, category, explanation
    }
}
