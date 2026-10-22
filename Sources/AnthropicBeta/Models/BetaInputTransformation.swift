import Anthropic

/// Why the API ruled on a block as it did. Ported from the `reason` literal shared by
/// `types/beta/beta_thinking_dropped_input_transformation.py` and
/// `beta_thinking_mismatch_allowed_input_transformation.py`.
public enum BetaInputTransformationReason: Sendable, Equatable {
    case modelBindingMismatch
    case prefixBindingMismatch
    case organizationBindingMismatch
    case endUserBindingMismatch
    case unknown(String)
}

extension BetaInputTransformationReason: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "model_binding_mismatch": self = .modelBindingMismatch
        case "prefix_binding_mismatch": self = .prefixBindingMismatch
        case "organization_binding_mismatch": self = .organizationBindingMismatch
        case "end_user_binding_mismatch": self = .endUserBindingMismatch
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .modelBindingMismatch: try container.encode("model_binding_mismatch")
        case .prefixBindingMismatch: try container.encode("prefix_binding_mismatch")
        case .organizationBindingMismatch: try container.encode("organization_binding_mismatch")
        case .endUserBindingMismatch: try container.encode("end_user_binding_mismatch")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// A `thinking`, `redacted_thinking` or `connector_text` block from the request that was removed from
/// the prompt instead of being shown to the model, because it failed a binding check. Ported from
/// `types/beta/beta_thinking_dropped_input_transformation.py`.
public struct BetaThinkingDroppedInputTransformation: Codable, Sendable, Equatable {
    public let type = "thinking_dropped"
    /// Where in the request the block sat.
    public let path: String
    public let reason: BetaInputTransformationReason

    private enum CodingKeys: String, CodingKey {
        case type, path, reason
    }
}

/// A `thinking` or `redacted_thinking` block that failed the conversation check but was shown to the
/// model all the same, because that check isn't enforced for this request. Ported from
/// `types/beta/beta_thinking_mismatch_allowed_input_transformation.py`.
public struct BetaThinkingMismatchAllowedInputTransformation: Codable, Sendable, Equatable {
    public let type = "thinking_mismatch_allowed"
    public let path: String
    public let reason: BetaInputTransformationReason

    private enum CodingKeys: String, CodingKey {
        case type, path, reason
    }
}

/// A change the API made to a request's input before showing it to the model, or a block that failed a
/// binding check but was left in place -- one entry per block, in request order. Ported from
/// `types/beta/beta_input_transformation.py`. More entry types may be added over time; the API says to
/// ignore ones you don't recognize, which `.unknown` makes possible.
///
/// Requires `anthropic-beta: thinking-binding-controls-2026-08-01`.
public enum BetaInputTransformation: Sendable, Equatable {
    case thinkingDropped(BetaThinkingDroppedInputTransformation)
    case thinkingMismatchAllowed(BetaThinkingMismatchAllowedInputTransformation)
    case unknown(type: String, raw: JSONValue)
}

extension BetaInputTransformation: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "thinking_dropped":
            self = .thinkingDropped(try BetaThinkingDroppedInputTransformation(from: decoder))
        case "thinking_mismatch_allowed":
            self = .thinkingMismatchAllowed(try BetaThinkingMismatchAllowedInputTransformation(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .thinkingDropped(let value): try value.encode(to: encoder)
        case .thinkingMismatchAllowed(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
