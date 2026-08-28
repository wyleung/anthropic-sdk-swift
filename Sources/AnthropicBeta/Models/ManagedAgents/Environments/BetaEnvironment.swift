/// Ported from `types/beta/beta_environment.py`. Environments are the persisted sandbox
/// configuration that Sessions run inside -- either an Anthropic-hosted `cloud` config or a
/// `self_hosted` one whose work queue this port exposes via `BetaEnvironmentWork`.
public struct BetaEnvironment: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let config: BetaEnvironmentConfig
    public let createdAt: String
    public let description: String?
    public let metadata: [String: String]
    public let name: String
    public let type: String
    public let updatedAt: String
    /// Only meaningful for self-hosted environments; `nil` on cloud environments.
    public let scope: BetaEnvironmentScope?

    public init(
        id: String, archivedAt: String? = nil, config: BetaEnvironmentConfig, createdAt: String,
        description: String? = nil, metadata: [String: String], name: String, type: String = "environment",
        updatedAt: String, scope: BetaEnvironmentScope? = nil
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.config = config
        self.createdAt = createdAt
        self.description = description
        self.metadata = metadata
        self.name = name
        self.type = type
        self.updatedAt = updatedAt
        self.scope = scope
    }
}

/// Ported from `types/beta/beta_environment_delete_response.py`.
public struct BetaEnvironmentDeleteResponse: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "environment_deleted") {
        self.id = id
        self.type = type
    }
}

/// Ported from the inline `Literal["organization", "account"]` used by both
/// `BetaEnvironment.scope` and the create/update params -- given its own type (rather than a bare
/// `String`) since it round-trips through both response and request bodies.
public enum BetaEnvironmentScope: Sendable, Equatable {
    case organization
    case account
    case unknown(String)
}

extension BetaEnvironmentScope: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "organization": self = .organization
        case "account": self = .account
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .organization: try container.encode("organization")
        case .account: try container.encode("account")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
