import Anthropic

/// Attribution for a write made by an agent during a session, through the mounted filesystem at
/// `/mnt/memory/`. Mirrors `types/beta/memory_stores/beta_managed_agents_session_actor.py`.
public struct BetaManagedAgentsSessionActor: Codable, Sendable, Equatable {
    public let sessionId: String
    public let type: String

    public init(sessionId: String, type: String = "session_actor") {
        self.sessionId = sessionId
        self.type = type
    }
}

/// Attribution for a write made directly via the public API (outside of any session). Mirrors
/// `types/beta/memory_stores/beta_managed_agents_api_actor.py`.
public struct BetaManagedAgentsAPIActor: Codable, Sendable, Equatable {
    public let apiKeyId: String
    public let type: String

    public init(apiKeyId: String, type: String = "api_actor") {
        self.apiKeyId = apiKeyId
        self.type = type
    }
}

/// Attribution for a write made by a human user through the Anthropic Console. Mirrors
/// `types/beta/memory_stores/beta_managed_agents_user_actor.py`.
public struct BetaManagedAgentsUserActor: Codable, Sendable, Equatable {
    public let type: String
    public let userId: String

    public init(type: String = "user_actor", userId: String) {
        self.type = type
        self.userId = userId
    }
}

/// Attribution for a write made by a workload authenticated as a service account, for example via
/// Workload Identity Federation. Mirrors
/// `types/beta/memory_stores/beta_managed_agents_service_account_actor.py`.
public struct BetaManagedAgentsServiceAccountActor: Codable, Sendable, Equatable {
    public let serviceAccountId: String
    public let type: String

    public init(serviceAccountId: String, type: String = "service_account_actor") {
        self.serviceAccountId = serviceAccountId
        self.type = type
    }
}

/// Identifies who performed a write or redact operation, captured at write time on a
/// `memory_version` row. Ported from `beta_managed_agents_actor.py` --
/// `Union[SessionActor, APIActor, UserActor, ServiceAccountActor]`, discriminated on `type`.
public enum BetaManagedAgentsActor: Sendable, Equatable {
    case session(BetaManagedAgentsSessionActor)
    case api(BetaManagedAgentsAPIActor)
    case user(BetaManagedAgentsUserActor)
    case serviceAccount(BetaManagedAgentsServiceAccountActor)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsActor: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "session_actor": self = .session(try BetaManagedAgentsSessionActor(from: decoder))
        case "api_actor": self = .api(try BetaManagedAgentsAPIActor(from: decoder))
        case "user_actor": self = .user(try BetaManagedAgentsUserActor(from: decoder))
        case "service_account_actor": self = .serviceAccount(try BetaManagedAgentsServiceAccountActor(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .session(let value): try value.encode(to: encoder)
        case .api(let value): try value.encode(to: encoder)
        case .user(let value): try value.encode(to: encoder)
        case .serviceAccount(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
