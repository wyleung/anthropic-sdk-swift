import Anthropic

/// The payload of an unwrapped webhook event, discriminated on `type`. Ported from
/// `types/beta/beta_webhook_event_data.py` -- a 44-member `Union` covering every resource that can
/// fire a webhook (Agents, Deployments, DeploymentRuns, Environments, MemoryStores, Sessions
/// (lifecycle/status/thread/outcome), Vaults, VaultCredentials). Every variant shares one of two
/// uniform shapes: the base `{id, organizationId, type, workspaceId}`, or that shape plus exactly
/// one extra identifier (`sessionThreadId` for the 3 thread variants, `vaultId` for the 4
/// vault-credential variants) -- confirmed by reading all 44 Python source files directly, not by
/// sampling.
public enum BetaWebhookEventData: Sendable, Equatable {
    case agentCreated(BetaWebhookAgentCreatedEventData)
    case agentUpdated(BetaWebhookAgentUpdatedEventData)
    case agentArchived(BetaWebhookAgentArchivedEventData)
    case agentDeleted(BetaWebhookAgentDeletedEventData)
    case deploymentCreated(BetaWebhookDeploymentCreatedEventData)
    case deploymentUpdated(BetaWebhookDeploymentUpdatedEventData)
    case deploymentArchived(BetaWebhookDeploymentArchivedEventData)
    case deploymentDeleted(BetaWebhookDeploymentDeletedEventData)
    case deploymentPaused(BetaWebhookDeploymentPausedEventData)
    case deploymentUnpaused(BetaWebhookDeploymentUnpausedEventData)
    case deploymentRunStarted(BetaWebhookDeploymentRunStartedEventData)
    case deploymentRunSucceeded(BetaWebhookDeploymentRunSucceededEventData)
    case deploymentRunFailed(BetaWebhookDeploymentRunFailedEventData)
    case environmentCreated(BetaWebhookEnvironmentCreatedEventData)
    case environmentUpdated(BetaWebhookEnvironmentUpdatedEventData)
    case environmentArchived(BetaWebhookEnvironmentArchivedEventData)
    case environmentDeleted(BetaWebhookEnvironmentDeletedEventData)
    case memoryStoreCreated(BetaWebhookMemoryStoreCreatedEventData)
    case memoryStoreArchived(BetaWebhookMemoryStoreArchivedEventData)
    case memoryStoreDeleted(BetaWebhookMemoryStoreDeletedEventData)
    case sessionCreated(BetaWebhookSessionCreatedEventData)
    case sessionPending(BetaWebhookSessionPendingEventData)
    case sessionRunning(BetaWebhookSessionRunningEventData)
    case sessionIdled(BetaWebhookSessionIdledEventData)
    case sessionRequiresAction(BetaWebhookSessionRequiresActionEventData)
    case sessionArchived(BetaWebhookSessionArchivedEventData)
    case sessionDeleted(BetaWebhookSessionDeletedEventData)
    case sessionUpdated(BetaWebhookSessionUpdatedEventData)
    case sessionBudgetReached(BetaWebhookSessionBudgetReachedEventData)
    case sessionStatusIdled(BetaWebhookSessionStatusIdledEventData)
    case sessionStatusRescheduled(BetaWebhookSessionStatusRescheduledEventData)
    case sessionStatusRunStarted(BetaWebhookSessionStatusRunStartedEventData)
    case sessionStatusTerminated(BetaWebhookSessionStatusTerminatedEventData)
    case sessionThreadCreated(BetaWebhookSessionThreadCreatedEventData)
    case sessionThreadIdled(BetaWebhookSessionThreadIdledEventData)
    case sessionThreadTerminated(BetaWebhookSessionThreadTerminatedEventData)
    case sessionOutcomeEvaluationEnded(BetaWebhookSessionOutcomeEvaluationEndedEventData)
    case vaultCreated(BetaWebhookVaultCreatedEventData)
    case vaultArchived(BetaWebhookVaultArchivedEventData)
    case vaultDeleted(BetaWebhookVaultDeletedEventData)
    case vaultCredentialCreated(BetaWebhookVaultCredentialCreatedEventData)
    case vaultCredentialArchived(BetaWebhookVaultCredentialArchivedEventData)
    case vaultCredentialDeleted(BetaWebhookVaultCredentialDeletedEventData)
    case vaultCredentialRefreshFailed(BetaWebhookVaultCredentialRefreshFailedEventData)
    case unknown(type: String, raw: JSONValue)
}

extension BetaWebhookEventData: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "agent.created": self = .agentCreated(try BetaWebhookAgentCreatedEventData(from: decoder))
        case "agent.updated": self = .agentUpdated(try BetaWebhookAgentUpdatedEventData(from: decoder))
        case "agent.archived": self = .agentArchived(try BetaWebhookAgentArchivedEventData(from: decoder))
        case "agent.deleted": self = .agentDeleted(try BetaWebhookAgentDeletedEventData(from: decoder))
        case "deployment.created":
            self = .deploymentCreated(try BetaWebhookDeploymentCreatedEventData(from: decoder))
        case "deployment.updated":
            self = .deploymentUpdated(try BetaWebhookDeploymentUpdatedEventData(from: decoder))
        case "deployment.archived":
            self = .deploymentArchived(try BetaWebhookDeploymentArchivedEventData(from: decoder))
        case "deployment.deleted":
            self = .deploymentDeleted(try BetaWebhookDeploymentDeletedEventData(from: decoder))
        case "deployment.paused":
            self = .deploymentPaused(try BetaWebhookDeploymentPausedEventData(from: decoder))
        case "deployment.unpaused":
            self = .deploymentUnpaused(try BetaWebhookDeploymentUnpausedEventData(from: decoder))
        case "deployment_run.started":
            self = .deploymentRunStarted(try BetaWebhookDeploymentRunStartedEventData(from: decoder))
        case "deployment_run.succeeded":
            self = .deploymentRunSucceeded(try BetaWebhookDeploymentRunSucceededEventData(from: decoder))
        case "deployment_run.failed":
            self = .deploymentRunFailed(try BetaWebhookDeploymentRunFailedEventData(from: decoder))
        case "environment.created":
            self = .environmentCreated(try BetaWebhookEnvironmentCreatedEventData(from: decoder))
        case "environment.updated":
            self = .environmentUpdated(try BetaWebhookEnvironmentUpdatedEventData(from: decoder))
        case "environment.archived":
            self = .environmentArchived(try BetaWebhookEnvironmentArchivedEventData(from: decoder))
        case "environment.deleted":
            self = .environmentDeleted(try BetaWebhookEnvironmentDeletedEventData(from: decoder))
        case "memory_store.created":
            self = .memoryStoreCreated(try BetaWebhookMemoryStoreCreatedEventData(from: decoder))
        case "memory_store.archived":
            self = .memoryStoreArchived(try BetaWebhookMemoryStoreArchivedEventData(from: decoder))
        case "memory_store.deleted":
            self = .memoryStoreDeleted(try BetaWebhookMemoryStoreDeletedEventData(from: decoder))
        case "session.created": self = .sessionCreated(try BetaWebhookSessionCreatedEventData(from: decoder))
        case "session.pending": self = .sessionPending(try BetaWebhookSessionPendingEventData(from: decoder))
        case "session.running": self = .sessionRunning(try BetaWebhookSessionRunningEventData(from: decoder))
        case "session.idled": self = .sessionIdled(try BetaWebhookSessionIdledEventData(from: decoder))
        case "session.requires_action":
            self = .sessionRequiresAction(try BetaWebhookSessionRequiresActionEventData(from: decoder))
        case "session.archived": self = .sessionArchived(try BetaWebhookSessionArchivedEventData(from: decoder))
        case "session.deleted": self = .sessionDeleted(try BetaWebhookSessionDeletedEventData(from: decoder))
        case "session.updated": self = .sessionUpdated(try BetaWebhookSessionUpdatedEventData(from: decoder))
        case "session.budget_reached":
            self = .sessionBudgetReached(try BetaWebhookSessionBudgetReachedEventData(from: decoder))
        case "session.status_idled":
            self = .sessionStatusIdled(try BetaWebhookSessionStatusIdledEventData(from: decoder))
        case "session.status_rescheduled":
            self = .sessionStatusRescheduled(try BetaWebhookSessionStatusRescheduledEventData(from: decoder))
        case "session.status_run_started":
            self = .sessionStatusRunStarted(try BetaWebhookSessionStatusRunStartedEventData(from: decoder))
        case "session.status_terminated":
            self = .sessionStatusTerminated(try BetaWebhookSessionStatusTerminatedEventData(from: decoder))
        case "session.thread_created":
            self = .sessionThreadCreated(try BetaWebhookSessionThreadCreatedEventData(from: decoder))
        case "session.thread_idled":
            self = .sessionThreadIdled(try BetaWebhookSessionThreadIdledEventData(from: decoder))
        case "session.thread_terminated":
            self = .sessionThreadTerminated(try BetaWebhookSessionThreadTerminatedEventData(from: decoder))
        case "session.outcome_evaluation_ended":
            self = .sessionOutcomeEvaluationEnded(
                try BetaWebhookSessionOutcomeEvaluationEndedEventData(from: decoder))
        case "vault.created": self = .vaultCreated(try BetaWebhookVaultCreatedEventData(from: decoder))
        case "vault.archived": self = .vaultArchived(try BetaWebhookVaultArchivedEventData(from: decoder))
        case "vault.deleted": self = .vaultDeleted(try BetaWebhookVaultDeletedEventData(from: decoder))
        case "vault_credential.created":
            self = .vaultCredentialCreated(try BetaWebhookVaultCredentialCreatedEventData(from: decoder))
        case "vault_credential.archived":
            self = .vaultCredentialArchived(try BetaWebhookVaultCredentialArchivedEventData(from: decoder))
        case "vault_credential.deleted":
            self = .vaultCredentialDeleted(try BetaWebhookVaultCredentialDeletedEventData(from: decoder))
        case "vault_credential.refresh_failed":
            self = .vaultCredentialRefreshFailed(
                try BetaWebhookVaultCredentialRefreshFailedEventData(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .agentCreated(let value): try value.encode(to: encoder)
        case .agentUpdated(let value): try value.encode(to: encoder)
        case .agentArchived(let value): try value.encode(to: encoder)
        case .agentDeleted(let value): try value.encode(to: encoder)
        case .deploymentCreated(let value): try value.encode(to: encoder)
        case .deploymentUpdated(let value): try value.encode(to: encoder)
        case .deploymentArchived(let value): try value.encode(to: encoder)
        case .deploymentDeleted(let value): try value.encode(to: encoder)
        case .deploymentPaused(let value): try value.encode(to: encoder)
        case .deploymentUnpaused(let value): try value.encode(to: encoder)
        case .deploymentRunStarted(let value): try value.encode(to: encoder)
        case .deploymentRunSucceeded(let value): try value.encode(to: encoder)
        case .deploymentRunFailed(let value): try value.encode(to: encoder)
        case .environmentCreated(let value): try value.encode(to: encoder)
        case .environmentUpdated(let value): try value.encode(to: encoder)
        case .environmentArchived(let value): try value.encode(to: encoder)
        case .environmentDeleted(let value): try value.encode(to: encoder)
        case .memoryStoreCreated(let value): try value.encode(to: encoder)
        case .memoryStoreArchived(let value): try value.encode(to: encoder)
        case .memoryStoreDeleted(let value): try value.encode(to: encoder)
        case .sessionCreated(let value): try value.encode(to: encoder)
        case .sessionPending(let value): try value.encode(to: encoder)
        case .sessionRunning(let value): try value.encode(to: encoder)
        case .sessionIdled(let value): try value.encode(to: encoder)
        case .sessionRequiresAction(let value): try value.encode(to: encoder)
        case .sessionArchived(let value): try value.encode(to: encoder)
        case .sessionDeleted(let value): try value.encode(to: encoder)
        case .sessionUpdated(let value): try value.encode(to: encoder)
        case .sessionBudgetReached(let value): try value.encode(to: encoder)
        case .sessionStatusIdled(let value): try value.encode(to: encoder)
        case .sessionStatusRescheduled(let value): try value.encode(to: encoder)
        case .sessionStatusRunStarted(let value): try value.encode(to: encoder)
        case .sessionStatusTerminated(let value): try value.encode(to: encoder)
        case .sessionThreadCreated(let value): try value.encode(to: encoder)
        case .sessionThreadIdled(let value): try value.encode(to: encoder)
        case .sessionThreadTerminated(let value): try value.encode(to: encoder)
        case .sessionOutcomeEvaluationEnded(let value): try value.encode(to: encoder)
        case .vaultCreated(let value): try value.encode(to: encoder)
        case .vaultArchived(let value): try value.encode(to: encoder)
        case .vaultDeleted(let value): try value.encode(to: encoder)
        case .vaultCredentialCreated(let value): try value.encode(to: encoder)
        case .vaultCredentialArchived(let value): try value.encode(to: encoder)
        case .vaultCredentialDeleted(let value): try value.encode(to: encoder)
        case .vaultCredentialRefreshFailed(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
