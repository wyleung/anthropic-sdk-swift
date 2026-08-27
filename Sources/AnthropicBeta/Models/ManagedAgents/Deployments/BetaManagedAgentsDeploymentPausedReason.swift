import Anthropic

/// An unrecognized error auto-paused the deployment -- a fallback variant; matches a run whose
/// `error.type` is `unknown_error`. Ported from
/// `beta_managed_agents_unknown_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsUnknownDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "unknown_error") { self.type = type }
}

/// The deployment's agent was archived. Ported from
/// `beta_managed_agents_agent_archived_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsAgentArchivedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "agent_archived_error") { self.type = type }
}

/// A file resource referenced by the deployment no longer exists. Ported from
/// `beta_managed_agents_file_not_found_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsFileNotFoundDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "file_not_found_error") { self.type = type }
}

/// A vault referenced by the deployment is archived. Ported from
/// `beta_managed_agents_vault_archived_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsVaultArchivedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "vault_archived_error") { self.type = type }
}

/// A skill referenced by the deployment's agent no longer exists. Ported from
/// `beta_managed_agents_skill_not_found_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsSkillNotFoundDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "skill_not_found_error") { self.type = type }
}

/// A vault referenced by the deployment no longer exists. Ported from
/// `beta_managed_agents_vault_not_found_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsVaultNotFoundDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "vault_not_found_error") { self.type = type }
}

/// An MCP server host used by the deployment's agent is blocked by the environment's network
/// policy. Ported from `beta_managed_agents_mcp_egress_blocked_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsMCPEgressBlockedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "mcp_egress_blocked_error") { self.type = type }
}

/// The deployment's workspace was archived. Ported from
/// `beta_managed_agents_workspace_archived_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsWorkspaceArchivedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "workspace_archived_error") { self.type = type }
}

/// The deployment's environment was archived. Ported from
/// `beta_managed_agents_environment_archived_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsEnvironmentArchivedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "environment_archived_error") { self.type = type }
}

/// The deployment's environment no longer exists. Ported from
/// `beta_managed_agents_environment_not_found_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsEnvironmentNotFoundDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "environment_not_found_error") { self.type = type }
}

/// A memory store referenced by the deployment is archived. Ported from
/// `beta_managed_agents_memory_store_archived_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsMemoryStoreArchivedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "memory_store_archived_error") { self.type = type }
}

/// The deployment's organization is disabled. Ported from
/// `beta_managed_agents_organization_disabled_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsOrganizationDisabledDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "organization_disabled_error") { self.type = type }
}

/// A referenced resource no longer exists and its kind was not reported. Ported from
/// `beta_managed_agents_session_resource_not_found_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsSessionResourceNotFoundDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "session_resource_not_found_error") { self.type = type }
}

/// The deployment configures resources, but its environment is self-hosted and cannot mount them.
/// Ported from
/// `beta_managed_agents_self_hosted_resources_unsupported_deployment_paused_reason_error.py`.
public struct BetaManagedAgentsSelfHostedResourcesUnsupportedDeploymentPausedReasonError: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "self_hosted_resources_unsupported_error") { self.type = type }
}

/// Ported from `beta_managed_agents_deployment_paused_reason_error.py` -- a 14-variant,
/// type-only union (no `message` field, unlike the 16-variant `BetaManagedAgentsDeploymentRunError`
/// per decision 7). All 14 case names here are a subset of the run-error union's 16, minus
/// `session_rate_limited_error`/`session_creation_rejected_error` which don't auto-pause the
/// parent deployment.
public enum BetaManagedAgentsDeploymentPausedReasonError: Sendable, Equatable {
    case environmentArchived(BetaManagedAgentsEnvironmentArchivedDeploymentPausedReasonError)
    case agentArchived(BetaManagedAgentsAgentArchivedDeploymentPausedReasonError)
    case environmentNotFound(BetaManagedAgentsEnvironmentNotFoundDeploymentPausedReasonError)
    case vaultNotFound(BetaManagedAgentsVaultNotFoundDeploymentPausedReasonError)
    case fileNotFound(BetaManagedAgentsFileNotFoundDeploymentPausedReasonError)
    case sessionResourceNotFound(BetaManagedAgentsSessionResourceNotFoundDeploymentPausedReasonError)
    case workspaceArchived(BetaManagedAgentsWorkspaceArchivedDeploymentPausedReasonError)
    case organizationDisabled(BetaManagedAgentsOrganizationDisabledDeploymentPausedReasonError)
    case memoryStoreArchived(BetaManagedAgentsMemoryStoreArchivedDeploymentPausedReasonError)
    case skillNotFound(BetaManagedAgentsSkillNotFoundDeploymentPausedReasonError)
    case vaultArchived(BetaManagedAgentsVaultArchivedDeploymentPausedReasonError)
    case unknownError(BetaManagedAgentsUnknownDeploymentPausedReasonError)
    case selfHostedResourcesUnsupported(BetaManagedAgentsSelfHostedResourcesUnsupportedDeploymentPausedReasonError)
    case mcpEgressBlocked(BetaManagedAgentsMCPEgressBlockedDeploymentPausedReasonError)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsDeploymentPausedReasonError: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "environment_archived_error":
            self = .environmentArchived(try BetaManagedAgentsEnvironmentArchivedDeploymentPausedReasonError(from: decoder))
        case "agent_archived_error":
            self = .agentArchived(try BetaManagedAgentsAgentArchivedDeploymentPausedReasonError(from: decoder))
        case "environment_not_found_error":
            self = .environmentNotFound(try BetaManagedAgentsEnvironmentNotFoundDeploymentPausedReasonError(from: decoder))
        case "vault_not_found_error":
            self = .vaultNotFound(try BetaManagedAgentsVaultNotFoundDeploymentPausedReasonError(from: decoder))
        case "file_not_found_error":
            self = .fileNotFound(try BetaManagedAgentsFileNotFoundDeploymentPausedReasonError(from: decoder))
        case "session_resource_not_found_error":
            self = .sessionResourceNotFound(
                try BetaManagedAgentsSessionResourceNotFoundDeploymentPausedReasonError(from: decoder))
        case "workspace_archived_error":
            self = .workspaceArchived(try BetaManagedAgentsWorkspaceArchivedDeploymentPausedReasonError(from: decoder))
        case "organization_disabled_error":
            self = .organizationDisabled(try BetaManagedAgentsOrganizationDisabledDeploymentPausedReasonError(from: decoder))
        case "memory_store_archived_error":
            self = .memoryStoreArchived(try BetaManagedAgentsMemoryStoreArchivedDeploymentPausedReasonError(from: decoder))
        case "skill_not_found_error":
            self = .skillNotFound(try BetaManagedAgentsSkillNotFoundDeploymentPausedReasonError(from: decoder))
        case "vault_archived_error":
            self = .vaultArchived(try BetaManagedAgentsVaultArchivedDeploymentPausedReasonError(from: decoder))
        case "unknown_error":
            self = .unknownError(try BetaManagedAgentsUnknownDeploymentPausedReasonError(from: decoder))
        case "self_hosted_resources_unsupported_error":
            self = .selfHostedResourcesUnsupported(
                try BetaManagedAgentsSelfHostedResourcesUnsupportedDeploymentPausedReasonError(from: decoder))
        case "mcp_egress_blocked_error":
            self = .mcpEgressBlocked(try BetaManagedAgentsMCPEgressBlockedDeploymentPausedReasonError(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .environmentArchived(let value): try value.encode(to: encoder)
        case .agentArchived(let value): try value.encode(to: encoder)
        case .environmentNotFound(let value): try value.encode(to: encoder)
        case .vaultNotFound(let value): try value.encode(to: encoder)
        case .fileNotFound(let value): try value.encode(to: encoder)
        case .sessionResourceNotFound(let value): try value.encode(to: encoder)
        case .workspaceArchived(let value): try value.encode(to: encoder)
        case .organizationDisabled(let value): try value.encode(to: encoder)
        case .memoryStoreArchived(let value): try value.encode(to: encoder)
        case .skillNotFound(let value): try value.encode(to: encoder)
        case .vaultArchived(let value): try value.encode(to: encoder)
        case .unknownError(let value): try value.encode(to: encoder)
        case .selfHostedResourcesUnsupported(let value): try value.encode(to: encoder)
        case .mcpEgressBlocked(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// The caller invoked the pause endpoint on the deployment. Ported from
/// `beta_managed_agents_manual_deployment_paused_reason.py`.
public struct BetaManagedAgentsManualDeploymentPausedReason: Codable, Sendable, Equatable {
    public let type: String
    public init(type: String = "manual") { self.type = type }
}

/// A scheduled fire recorded a failed run whose error auto-pauses the deployment. Ported from
/// `beta_managed_agents_error_deployment_paused_reason.py`.
public struct BetaManagedAgentsErrorDeploymentPausedReason: Codable, Sendable, Equatable {
    public let error: BetaManagedAgentsDeploymentPausedReasonError
    public let type: String

    public init(error: BetaManagedAgentsDeploymentPausedReasonError, type: String = "error") {
        self.error = error
        self.type = type
    }
}

/// Why a deployment is paused; non-null exactly when `status` is `paused`. Ported from
/// `beta_managed_agents_deployment_paused_reason.py` --
/// `Union[BetaManagedAgentsManualDeploymentPausedReason, BetaManagedAgentsErrorDeploymentPausedReason]`,
/// discriminated on `type`.
public enum BetaManagedAgentsDeploymentPausedReason: Sendable, Equatable {
    case manual(BetaManagedAgentsManualDeploymentPausedReason)
    case error(BetaManagedAgentsErrorDeploymentPausedReason)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsDeploymentPausedReason: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "manual": self = .manual(try BetaManagedAgentsManualDeploymentPausedReason(from: decoder))
        case "error": self = .error(try BetaManagedAgentsErrorDeploymentPausedReason(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .manual(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
