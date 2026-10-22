import Anthropic

/// Controls how thinking content appears in the response. Ported from the `display` literal on
/// `types/beta/beta_thinking_config_{enabled,adaptive}_param.py`. GA's `ThinkingConfigDisplay` has no
/// `updates` case, which is why Beta needs its own.
public enum BetaThinkingConfigDisplay: String, Encodable, Sendable, Equatable {
    case summarized
    case omitted
    case updates
}

/// What happens when a thinking block the request sends back fails the conversation check. Ported from
/// `types/beta/beta_thinking_prefix_mismatch_behavior.py`.
public enum BetaThinkingPrefixMismatchBehavior: String, Encodable, Sendable, Equatable {
    /// Fail the request with a 400 error (the server default).
    case error
    /// Remove the failing blocks and proceed; each removal is reported in `inputTransformations`.
    case dropBlock = "drop_block"
}

/// Controls for block binding: what happens when a thinking block this request sends back fails the
/// conversation check (created in a different conversation, or the messages before it have changed).
/// Every field is optional; an empty value means every default. Ported from
/// `types/beta/beta_thinking_block_binding_param.py`. Requires
/// `anthropic-beta: thinking-binding-controls-2026-08-01`.
public struct BetaThinkingBlockBindingParam: Encodable, Sendable, Equatable {
    public let prefixMismatchBehavior: BetaThinkingPrefixMismatchBehavior?

    public init(prefixMismatchBehavior: BetaThinkingPrefixMismatchBehavior? = nil) {
        self.prefixMismatchBehavior = prefixMismatchBehavior
    }
}

public struct BetaThinkingConfigEnabledParam: Encodable, Sendable, Equatable {
    public let type = "enabled"
    /// How many tokens Claude can use for internal reasoning: at least 1024 and less than `maxTokens`.
    public let budgetTokens: Int
    public let blockBinding: BetaThinkingBlockBindingParam?
    public let display: BetaThinkingConfigDisplay?

    public init(
        budgetTokens: Int, blockBinding: BetaThinkingBlockBindingParam? = nil, display: BetaThinkingConfigDisplay? = nil
    ) {
        self.budgetTokens = budgetTokens
        self.blockBinding = blockBinding
        self.display = display
    }
}

public struct BetaThinkingConfigDisabledParam: Encodable, Sendable, Equatable {
    public let type = "disabled"

    public init() {}
}

/// Thinking between tool calls. Ported from `types/beta/beta_thinking_config_between_tools_param.py`.
public struct BetaThinkingConfigBetweenToolsParam: Encodable, Sendable, Equatable {
    public let type = "between_tools"

    public init() {}
}

public struct BetaThinkingConfigAdaptiveParam: Encodable, Sendable, Equatable {
    public let type = "adaptive"
    public let blockBinding: BetaThinkingBlockBindingParam?
    public let display: BetaThinkingConfigDisplay?

    public init(blockBinding: BetaThinkingBlockBindingParam? = nil, display: BetaThinkingConfigDisplay? = nil) {
        self.blockBinding = blockBinding
        self.display = display
    }
}

/// Ported from `types/beta/beta_thinking_config_param.py`. Distinct from GA's `ThinkingConfigParam`:
/// Beta's enabled/adaptive configs carry `blockBinding` and a wider `display`, which GA's API does not
/// accept.
public enum BetaThinkingConfigParam: Sendable, Equatable {
    case enabled(BetaThinkingConfigEnabledParam)
    case disabled(BetaThinkingConfigDisabledParam)
    case betweenTools(BetaThinkingConfigBetweenToolsParam)
    case adaptive(BetaThinkingConfigAdaptiveParam)
}

extension BetaThinkingConfigParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .enabled(let value): try value.encode(to: encoder)
        case .disabled(let value): try value.encode(to: encoder)
        case .betweenTools(let value): try value.encode(to: encoder)
        case .adaptive(let value): try value.encode(to: encoder)
        }
    }
}

extension BetaThinkingConfigParam {
    /// Beta used to take GA's `ThinkingConfigParam`; this keeps existing call sites a one-token change.
    public init(_ ga: ThinkingConfigParam) {
        func display(_ ga: ThinkingConfigDisplay?) -> BetaThinkingConfigDisplay? {
            switch ga {
            case .summarized: return .summarized
            case .omitted: return .omitted
            case nil: return nil
            }
        }
        switch ga {
        case .enabled(let value):
            self = .enabled(BetaThinkingConfigEnabledParam(budgetTokens: value.budgetTokens, display: display(value.display)))
        case .disabled:
            self = .disabled(BetaThinkingConfigDisabledParam())
        case .betweenTools:
            self = .betweenTools(BetaThinkingConfigBetweenToolsParam())
        case .adaptive(let value):
            self = .adaptive(BetaThinkingConfigAdaptiveParam(display: display(value.display)))
        }
    }
}
