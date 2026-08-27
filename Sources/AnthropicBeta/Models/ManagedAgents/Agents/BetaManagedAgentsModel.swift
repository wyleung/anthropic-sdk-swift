import Anthropic

/// Ported from `beta_managed_agents_model.py` / `beta_managed_agents_model_param.py`, both
/// `Union[Literal[13 known model ids], str]` -- collapsed into a single plain `String` alias here,
/// matching this codebase's existing convention of treating model identifiers as unconstrained
/// strings (see `MessageCreateParams.model`) rather than a closed enum that would need updating
/// every time Anthropic ships a new model.
public typealias BetaManagedAgentsModel = String

/// A resolved model configuration, as returned in a `BetaManagedAgentsAgent` response. Unlike the
/// params side (`BetaManagedAgentsModelConfigParams`), the response's `model` field is always this
/// fully-resolved object -- never a bare model-id string.
public struct BetaManagedAgentsModelConfig: Codable, Sendable, Equatable {
    public let id: BetaManagedAgentsModel
    public let effort: BetaManagedAgentsEffort?
    public let inferenceGeo: String?
    public let speed: BetaManagedAgentsModelSpeed?

    public init(
        id: BetaManagedAgentsModel,
        effort: BetaManagedAgentsEffort? = nil,
        inferenceGeo: String? = nil,
        speed: BetaManagedAgentsModelSpeed? = nil
    ) {
        self.id = id
        self.effort = effort
        self.inferenceGeo = inferenceGeo
        self.speed = speed
    }
}

/// Ported from `beta_managed_agents_model_config_params.py`.
public struct BetaManagedAgentsModelConfigParams: Encodable, Sendable, Equatable {
    public let id: BetaManagedAgentsModel
    public let effort: BetaManagedAgentsEffort?
    public let inferenceGeo: String?
    public let speed: BetaManagedAgentsModelSpeed?

    public init(
        id: BetaManagedAgentsModel,
        effort: BetaManagedAgentsEffort? = nil,
        inferenceGeo: String? = nil,
        speed: BetaManagedAgentsModelSpeed? = nil
    ) {
        self.id = id
        self.effort = effort
        self.inferenceGeo = inferenceGeo
        self.speed = speed
    }
}

/// Ported from the `Effort` (response) / effort-level params type aliases
/// (`beta_managed_agents_effort_{low,medium,high,xhigh,max}(_param).py`). Every variant is a
/// trivial single-field `{"type": "..."}` wrapper, so this collapses to one enum shared by both
/// directions -- but the two directions are asymmetric:
///
/// - **Encoding** always emits a bare string (e.g. `"high"`), per the params docstring: "Accepts a
///   bare level string ... or `{"type": "high"}`". A bare string is always valid to send, so the
///   object form is never needed on the wire even though Python's params type permits it.
/// - **Decoding** always reads a keyed `{"type": "..."}` object, since the response's `Effort`
///   type alias is `Annotated[Union[EffortLow, ..., EffortMax], discriminator="type"]` with no
///   bare-string member -- a response never sends a bare string.
public enum BetaManagedAgentsEffort: Sendable, Equatable {
    case low
    case medium
    case high
    case xhigh
    case max
    case unknown(String)
}

extension BetaManagedAgentsEffort: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        self = BetaManagedAgentsEffort(wireValue: type)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }

    private init(wireValue: String) {
        switch wireValue {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "xhigh": self = .xhigh
        case "max": self = .max
        default: self = .unknown(wireValue)
        }
    }

    private var wireValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .xhigh: return "xhigh"
        case .max: return "max"
        case .unknown(let value): return value
        }
    }
}

/// Ported from `beta_managed_agents_model_config.py`'s `speed` field
/// (`Optional[Literal["standard", "fast"]]`) -- a small closed set with a forward-compat fallback,
/// mirroring `BetaEnvironmentScope`'s bare-string `Codable` pattern.
public enum BetaManagedAgentsModelSpeed: Sendable, Equatable {
    case standard
    case fast
    case unknown(String)
}

extension BetaManagedAgentsModelSpeed: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "standard": self = .standard
        case "fast": self = .fast
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .standard: try container.encode("standard")
        case .fast: try container.encode("fast")
        case .unknown(let value): try container.encode(value)
        }
    }
}

/// Ported from `agent_create_params.py`/`agent_update_params.py`'s `model` field type
/// (`Union[ModelParam, ModelConfigParams]`) -- either a bare model-id string or a full model
/// config object. Mirrors `MessageCreateParamsContainerParam`'s bare-value-or-object union
/// pattern.
public enum BetaAgentModelParam: Sendable, Equatable {
    case model(BetaManagedAgentsModel)
    case config(BetaManagedAgentsModelConfigParams)
}

extension BetaAgentModelParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .model(let value): try container.encode(value)
        case .config(let value): try container.encode(value)
        }
    }
}

extension BetaAgentModelParam: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .model(value)
    }
}
