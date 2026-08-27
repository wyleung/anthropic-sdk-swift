import Anthropic

/// The 16 leaf error types a `BetaManagedAgentsDeploymentRun` can report, each ported from its own
/// `beta_managed_agents_*_run_error.py` file. Distinct from `BetaManagedAgentsDeploymentPausedReasonError`
/// (14 variants, type-only `{type}`): these are message-bearing (`{message, type}`) and add 2 extra
/// variants -- `sessionRateLimited`/`sessionCreationRejected` -- that fail a single run without
/// pausing the parent deployment. Confirmed by direct name comparison against
/// `beta_managed_agents_deployment_run.py`'s declared `Error` union: all 14 paused-reason names
/// reappear here verbatim, plus exactly those 2 additions -- the 14 are a strict subset of these 16.
public struct BetaManagedAgentsEnvironmentArchivedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "environment_archived_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsAgentArchivedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "agent_archived_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsEnvironmentNotFoundRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "environment_not_found_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsVaultNotFoundRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "vault_not_found_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsVaultArchivedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "vault_archived_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsFileNotFoundRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "file_not_found_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsMemoryStoreArchivedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "memory_store_archived_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsSkillNotFoundRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "skill_not_found_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsSessionResourceNotFoundRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "session_resource_not_found_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsWorkspaceArchivedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "workspace_archived_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsOrganizationDisabledRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "organization_disabled_error") {
        self.message = message
        self.type = type
    }
}

/// The schedule keeps firing; subsequent runs may succeed.
public struct BetaManagedAgentsSessionRateLimitedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "session_rate_limited_error") {
        self.message = message
        self.type = type
    }
}

/// The session create request was rejected with a non-retryable validation error.
public struct BetaManagedAgentsSessionCreationRejectedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "session_creation_rejected_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsUnknownRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "unknown_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsSelfHostedResourcesUnsupportedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "self_hosted_resources_unsupported_error") {
        self.message = message
        self.type = type
    }
}

public struct BetaManagedAgentsMCPEgressBlockedRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String

    public init(message: String, type: String = "mcp_egress_blocked_error") {
        self.message = message
        self.type = type
    }
}

/// Ported from `beta_managed_agents_deployment_run.py`'s local `Error` `TypeAlias`. Exact declared
/// order preserved to match Python. `.unknown` handles any future variant.
public enum BetaManagedAgentsDeploymentRunError: Sendable, Equatable {
    case environmentArchived(BetaManagedAgentsEnvironmentArchivedRunError)
    case agentArchived(BetaManagedAgentsAgentArchivedRunError)
    case environmentNotFound(BetaManagedAgentsEnvironmentNotFoundRunError)
    case vaultNotFound(BetaManagedAgentsVaultNotFoundRunError)
    case vaultArchived(BetaManagedAgentsVaultArchivedRunError)
    case fileNotFound(BetaManagedAgentsFileNotFoundRunError)
    case memoryStoreArchived(BetaManagedAgentsMemoryStoreArchivedRunError)
    case skillNotFound(BetaManagedAgentsSkillNotFoundRunError)
    case sessionResourceNotFound(BetaManagedAgentsSessionResourceNotFoundRunError)
    case workspaceArchived(BetaManagedAgentsWorkspaceArchivedRunError)
    case organizationDisabled(BetaManagedAgentsOrganizationDisabledRunError)
    case sessionRateLimited(BetaManagedAgentsSessionRateLimitedRunError)
    case sessionCreationRejected(BetaManagedAgentsSessionCreationRejectedRunError)
    case unknownError(BetaManagedAgentsUnknownRunError)
    case selfHostedResourcesUnsupported(BetaManagedAgentsSelfHostedResourcesUnsupportedRunError)
    case mcpEgressBlocked(BetaManagedAgentsMCPEgressBlockedRunError)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsDeploymentRunError: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "environment_archived_error":
            self = .environmentArchived(try BetaManagedAgentsEnvironmentArchivedRunError(from: decoder))
        case "agent_archived_error":
            self = .agentArchived(try BetaManagedAgentsAgentArchivedRunError(from: decoder))
        case "environment_not_found_error":
            self = .environmentNotFound(try BetaManagedAgentsEnvironmentNotFoundRunError(from: decoder))
        case "vault_not_found_error":
            self = .vaultNotFound(try BetaManagedAgentsVaultNotFoundRunError(from: decoder))
        case "vault_archived_error":
            self = .vaultArchived(try BetaManagedAgentsVaultArchivedRunError(from: decoder))
        case "file_not_found_error":
            self = .fileNotFound(try BetaManagedAgentsFileNotFoundRunError(from: decoder))
        case "memory_store_archived_error":
            self = .memoryStoreArchived(try BetaManagedAgentsMemoryStoreArchivedRunError(from: decoder))
        case "skill_not_found_error":
            self = .skillNotFound(try BetaManagedAgentsSkillNotFoundRunError(from: decoder))
        case "session_resource_not_found_error":
            self = .sessionResourceNotFound(try BetaManagedAgentsSessionResourceNotFoundRunError(from: decoder))
        case "workspace_archived_error":
            self = .workspaceArchived(try BetaManagedAgentsWorkspaceArchivedRunError(from: decoder))
        case "organization_disabled_error":
            self = .organizationDisabled(try BetaManagedAgentsOrganizationDisabledRunError(from: decoder))
        case "session_rate_limited_error":
            self = .sessionRateLimited(try BetaManagedAgentsSessionRateLimitedRunError(from: decoder))
        case "session_creation_rejected_error":
            self = .sessionCreationRejected(try BetaManagedAgentsSessionCreationRejectedRunError(from: decoder))
        case "unknown_error":
            self = .unknownError(try BetaManagedAgentsUnknownRunError(from: decoder))
        case "self_hosted_resources_unsupported_error":
            self = .selfHostedResourcesUnsupported(
                try BetaManagedAgentsSelfHostedResourcesUnsupportedRunError(from: decoder))
        case "mcp_egress_blocked_error":
            self = .mcpEgressBlocked(try BetaManagedAgentsMCPEgressBlockedRunError(from: decoder))
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
        case .vaultArchived(let value): try value.encode(to: encoder)
        case .fileNotFound(let value): try value.encode(to: encoder)
        case .memoryStoreArchived(let value): try value.encode(to: encoder)
        case .skillNotFound(let value): try value.encode(to: encoder)
        case .sessionResourceNotFound(let value): try value.encode(to: encoder)
        case .workspaceArchived(let value): try value.encode(to: encoder)
        case .organizationDisabled(let value): try value.encode(to: encoder)
        case .sessionRateLimited(let value): try value.encode(to: encoder)
        case .sessionCreationRejected(let value): try value.encode(to: encoder)
        case .unknownError(let value): try value.encode(to: encoder)
        case .selfHostedResourcesUnsupported(let value): try value.encode(to: encoder)
        case .mcpEgressBlocked(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
