public enum ThinkingConfigDisplay: String, Encodable, Sendable, Equatable {
    case summarized
    case omitted
}

public struct ThinkingConfigEnabledParam: Encodable, Sendable, Equatable {
    public let type = "enabled"
    public let budgetTokens: Int
    public let display: ThinkingConfigDisplay?

    public init(budgetTokens: Int, display: ThinkingConfigDisplay? = nil) {
        self.budgetTokens = budgetTokens
        self.display = display
    }
}

public struct ThinkingConfigDisabledParam: Encodable, Sendable, Equatable {
    public let type = "disabled"

    public init() {}
}

public struct ThinkingConfigAdaptiveParam: Encodable, Sendable, Equatable {
    public let type = "adaptive"
    public let display: ThinkingConfigDisplay?

    public init(display: ThinkingConfigDisplay? = nil) {
        self.display = display
    }
}

public enum ThinkingConfigParam: Sendable, Equatable {
    case enabled(ThinkingConfigEnabledParam)
    case disabled(ThinkingConfigDisabledParam)
    case adaptive(ThinkingConfigAdaptiveParam)
}

extension ThinkingConfigParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let value): try value.encode(to: encoder)
        case .disabled(let value): try value.encode(to: encoder)
        case .adaptive(let value): try value.encode(to: encoder)
        }
    }
}
