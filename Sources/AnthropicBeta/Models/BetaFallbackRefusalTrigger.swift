/// Ported from `types/beta/beta_fallback_refusal_trigger.py`. Response-only (the param side's
/// `trigger` is an untyped, ignored-by-server `object`, so it has no typed counterpart). `category`
/// follows `BetaStopReason`'s open-enum-with-`.unknown` convention rather than plain `String?`, since
/// it's a server-controlled closed set that may grow.
public struct BetaFallbackRefusalTrigger: Sendable, Equatable {
    public enum Category: Sendable, Equatable {
        case cyber
        case bio
        case frontierLLM
        case reasoningExtraction
        case generalHarms
        case unknown(String)
    }

    public let category: Category?
    public let type = "refusal"

    public init(category: Category?) {
        self.category = category
    }
}

extension BetaFallbackRefusalTrigger.Category: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "cyber": self = .cyber
        case "bio": self = .bio
        case "frontier_llm": self = .frontierLLM
        case "reasoning_extraction": self = .reasoningExtraction
        case "general_harms": self = .generalHarms
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .cyber: try container.encode("cyber")
        case .bio: try container.encode("bio")
        case .frontierLLM: try container.encode("frontier_llm")
        case .reasoningExtraction: try container.encode("reasoning_extraction")
        case .generalHarms: try container.encode("general_harms")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

extension BetaFallbackRefusalTrigger: Codable {
    private enum CodingKeys: String, CodingKey {
        case category, type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.category = try container.decodeIfPresent(Category.self, forKey: .category)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(type, forKey: .type)
    }
}
