import Anthropic

/// Ported from `beta_managed_agents_deployment_initial_event_params.py` --
/// `Union[BetaManagedAgentsUserMessageEventParams, BetaManagedAgentsUserDefineOutcomeEventParams, BetaManagedAgentsSystemMessageEventParams]`.
/// Distinct from the session-side `BetaManagedAgentsInitialEventParam` (only 2 cases) -- this is
/// the 3-case union `DeploymentCreateParams`/`DeploymentUpdateParams` need for `initialEvents`.
/// Request-only (no `.unknown`); each leaf carries its own fixed `type` literal, so `encode(to:)`
/// is a plain switch. Reuses `BetaManagedAgentsUserMessageEventParams`/
/// `BetaManagedAgentsUserDefineOutcomeEventParams` (`BetaManagedAgentsSessionInitialEventParams.swift`)
/// and `BetaManagedAgentsSystemMessageEventParams` (`BetaManagedAgentsSendSessionEvents.swift`).
public enum BetaManagedAgentsDeploymentInitialEventParam: Sendable, Equatable {
    case userMessage(BetaManagedAgentsUserMessageEventParams)
    case userDefineOutcome(BetaManagedAgentsUserDefineOutcomeEventParams)
    case systemMessage(BetaManagedAgentsSystemMessageEventParams)
}

extension BetaManagedAgentsDeploymentInitialEventParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let value): try value.encode(to: encoder)
        case .userDefineOutcome(let value): try value.encode(to: encoder)
        case .systemMessage(let value): try value.encode(to: encoder)
        }
    }
}
