import Anthropic

/// One phase of a workflow run. Ported from `sessions/beta_managed_agents_workflow_run_phase.py`.
public struct BetaManagedAgentsWorkflowRunPhase: Codable, Sendable, Equatable {
    public let id: String
    public let description: String?
    public let name: String
}

// MARK: - errors

/// The workflow run exceeded its time limit. Ported from `beta_managed_agents_timeout_workflow_run_error.py`.
public struct BetaManagedAgentsTimeoutWorkflowRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// The workflow's program failed. Ported from `beta_managed_agents_program_workflow_run_error.py`.
public struct BetaManagedAgentsProgramWorkflowRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// An unclassified workflow-run failure. Ported from `beta_managed_agents_unknown_workflow_run_error.py`.
public struct BetaManagedAgentsUnknownWorkflowRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// The run hit the session's thread limit. Ported from `beta_managed_agents_thread_limit_workflow_run_error.py`.
public struct BetaManagedAgentsThreadLimitWorkflowRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// The session hit its cap on concurrent workflow runs. Ported from
/// `beta_managed_agents_max_workflow_runs_workflow_run_error.py`.
public struct BetaManagedAgentsMaxWorkflowRunsWorkflowRunError: Codable, Sendable, Equatable {
    public let message: String
    public let type: String
}

/// Why a workflow run failed. Ported from `beta_managed_agents_workflow_run_error.py`. `.unknownError` is
/// the wire's own `unknown_error` variant; `.unknown` is the fallback for a type newer than this port.
public enum BetaManagedAgentsWorkflowRunError: Sendable, Equatable {
    case timeout(BetaManagedAgentsTimeoutWorkflowRunError)
    case program(BetaManagedAgentsProgramWorkflowRunError)
    case unknownError(BetaManagedAgentsUnknownWorkflowRunError)
    case threadLimit(BetaManagedAgentsThreadLimitWorkflowRunError)
    case maxWorkflowRuns(BetaManagedAgentsMaxWorkflowRunsWorkflowRunError)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsWorkflowRunError: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "timeout_error": self = .timeout(try BetaManagedAgentsTimeoutWorkflowRunError(from: decoder))
        case "program_error": self = .program(try BetaManagedAgentsProgramWorkflowRunError(from: decoder))
        case "unknown_error": self = .unknownError(try BetaManagedAgentsUnknownWorkflowRunError(from: decoder))
        case "thread_limit_error": self = .threadLimit(try BetaManagedAgentsThreadLimitWorkflowRunError(from: decoder))
        case "max_workflow_runs_error":
            self = .maxWorkflowRuns(try BetaManagedAgentsMaxWorkflowRunsWorkflowRunError(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .timeout(let value): try value.encode(to: encoder)
        case .program(let value): try value.encode(to: encoder)
        case .unknownError(let value): try value.encode(to: encoder)
        case .threadLimit(let value): try value.encode(to: encoder)
        case .maxWorkflowRuns(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

// MARK: - results

/// The run finished successfully. Ported from `beta_managed_agents_workflow_run_result_completed.py`.
public struct BetaManagedAgentsWorkflowRunResultCompleted: Codable, Sendable, Equatable {
    public let type: String
}

/// The run ended in an error. Ported from `beta_managed_agents_workflow_run_result_error.py`.
public struct BetaManagedAgentsWorkflowRunResultError: Codable, Sendable, Equatable {
    public let error: BetaManagedAgentsWorkflowRunError
    public let type: String
}

/// The run was stopped before completing. Ported from `beta_managed_agents_workflow_run_result_stopped.py`.
public struct BetaManagedAgentsWorkflowRunResultStopped: Codable, Sendable, Equatable {
    public let type: String
}

/// How a workflow run ended. Ported from `beta_managed_agents_workflow_run_result.py`.
public enum BetaManagedAgentsWorkflowRunResult: Sendable, Equatable {
    case completed(BetaManagedAgentsWorkflowRunResultCompleted)
    case error(BetaManagedAgentsWorkflowRunResultError)
    case stopped(BetaManagedAgentsWorkflowRunResultStopped)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsWorkflowRunResult: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "completed": self = .completed(try BetaManagedAgentsWorkflowRunResultCompleted(from: decoder))
        case "error": self = .error(try BetaManagedAgentsWorkflowRunResultError(from: decoder))
        case "stopped": self = .stopped(try BetaManagedAgentsWorkflowRunResultStopped(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .completed(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .stopped(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

// MARK: - events

/// A workflow run was created. Ported from `sessions/beta_managed_agents_workflow_run_created_event.py`.
public struct BetaManagedAgentsWorkflowRunCreatedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let description: String?
    public let name: String
    public let phases: [BetaManagedAgentsWorkflowRunPhase]
    public let processedAt: String
    public let type: String
    public let workflowRunId: String
}

/// The run started or resumed. Ported from `..._workflow_run_status_running_event.py`.
public struct BetaManagedAgentsWorkflowRunStatusRunningEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String
    public let workflowRunId: String
}

/// The run went idle. Ported from `..._workflow_run_status_idle_event.py`.
public struct BetaManagedAgentsWorkflowRunStatusIdleEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String
    public let workflowRunId: String
}

/// The run ended, with its result. Ported from `..._workflow_run_status_ended_event.py`.
public struct BetaManagedAgentsWorkflowRunStatusEndedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let result: BetaManagedAgentsWorkflowRunResult
    public let type: String
    public let workflowRunId: String
}

/// A workflow run reported an error. `workflowRunId` is absent when the error isn't tied to one run.
/// Ported from `..._workflow_run_error_event.py`.
public struct BetaManagedAgentsWorkflowRunErrorEvent: Codable, Sendable, Equatable {
    public let id: String
    public let error: BetaManagedAgentsWorkflowRunError
    public let processedAt: String
    public let type: String
    public let workflowRunId: String?
}

/// A phase of the run began. Ported from `..._workflow_run_phase_started_event.py`.
public struct BetaManagedAgentsWorkflowRunPhaseStartedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let processedAt: String
    public let type: String
    public let workflowRunId: String
    public let workflowRunPhaseId: String
}

/// A phase of the run ended; `phaseStartedId` is the id of the matching started event. Ported from
/// `..._workflow_run_phase_ended_event.py`.
public struct BetaManagedAgentsWorkflowRunPhaseEndedEvent: Codable, Sendable, Equatable {
    public let id: String
    public let phaseStartedId: String
    public let processedAt: String
    public let type: String
    public let workflowRunId: String
    public let workflowRunPhaseId: String
}
