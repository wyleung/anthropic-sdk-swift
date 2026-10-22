import Anthropic

/// A run's execution principal when it is a customer-named AWS role. Ported from
/// `beta_managed_agents_aws_role_execution_identity.py`.
public struct BetaManagedAgentsAWSRoleExecutionIdentity: Codable, Sendable, Equatable {
    public let roleArn: String
    public let type = "aws_role"

    public init(roleArn: String) {
        self.roleArn = roleArn
    }

    private enum CodingKeys: String, CodingKey {
        case roleArn, type
    }
}

/// The default principal: runs carry no customer-named identity. Ported from
/// `beta_managed_agents_service_account_execution_identity.py`.
public struct BetaManagedAgentsServiceAccountExecutionIdentity: Codable, Sendable, Equatable {
    public let type = "service_account"

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// The execution principal for runs of an agent, as returned. Ported from
/// `beta_managed_agents_execution_identity.py`. Upstream says it is always present, with
/// `{"type": "service_account"}` when runs carry no customer-named principal; it is optional here only
/// because it postdates this port, so a response without it must still decode.
public enum BetaManagedAgentsExecutionIdentity: Sendable, Equatable {
    case awsRole(BetaManagedAgentsAWSRoleExecutionIdentity)
    case serviceAccount(BetaManagedAgentsServiceAccountExecutionIdentity)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsExecutionIdentity: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "aws_role": self = .awsRole(try BetaManagedAgentsAWSRoleExecutionIdentity(from: decoder))
        case "service_account": self = .serviceAccount(try BetaManagedAgentsServiceAccountExecutionIdentity(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .awsRole(let value): try value.encode(to: encoder)
        case .serviceAccount(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// The execution principal to set on create or update. Ported from
/// `beta_managed_agents_execution_identity_params.py` (its two variants are
/// `..._aws_role_execution_identity_params.py` and `..._service_account_execution_identity_params.py`).
///
/// Omit it to take the default on create, or to preserve the current one on update. `.serviceAccount`
/// restores the default -- upstream treats it as equivalent to sending `null`, which is why a plain
/// optional is enough and no explicit-null encoding is needed.
public enum BetaManagedAgentsExecutionIdentityParams: Sendable, Equatable {
    case awsRole(roleArn: String)
    case serviceAccount
}

extension BetaManagedAgentsExecutionIdentityParams: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, roleArn
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .awsRole(let roleArn):
            try container.encode("aws_role", forKey: .type)
            try container.encode(roleArn, forKey: .roleArn)
        case .serviceAccount:
            try container.encode("service_account", forKey: .type)
        }
    }
}
