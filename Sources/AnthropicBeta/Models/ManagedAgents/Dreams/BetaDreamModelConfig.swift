import Anthropic

/// Model identifier and configuration applied to every pipeline stage of a Dream. Same wire shape
/// as the Agents API `ModelConfig`, but deliberately modeled as its own small type here (not
/// reused from `BetaManagedAgentsModelConfig`) since Dream's config carries only `id`/`speed` --
/// no `effort`/`inferenceGeo`. Ported from `beta_dream_model_config.py`.
public struct BetaDreamModelConfig: Codable, Sendable, Equatable {
    public let id: String
    public let speed: BetaManagedAgentsModelSpeed?

    public init(id: String, speed: BetaManagedAgentsModelSpeed? = nil) {
        self.id = id
        self.speed = speed
    }
}

/// Request-side counterpart to `BetaDreamModelConfig`. Ported from `beta_dream_model_config_param.py`.
public struct BetaDreamModelConfigParams: Encodable, Sendable, Equatable {
    public let id: String
    public let speed: BetaManagedAgentsModelSpeed?

    public init(id: String, speed: BetaManagedAgentsModelSpeed? = nil) {
        self.id = id
        self.speed = speed
    }
}

/// Ported from `dream_create_params.py`'s `Model` type alias -- `Union[str, BetaDreamModelConfigParam]`,
/// mirroring `BetaAgentModelParam`'s bare-value-or-object union pattern.
public enum BetaDreamModelParam: Sendable, Equatable {
    case model(String)
    case config(BetaDreamModelConfigParams)
}

extension BetaDreamModelParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .model(let value): try container.encode(value)
        case .config(let value): try container.encode(value)
        }
    }
}

extension BetaDreamModelParam: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .model(value)
    }
}
