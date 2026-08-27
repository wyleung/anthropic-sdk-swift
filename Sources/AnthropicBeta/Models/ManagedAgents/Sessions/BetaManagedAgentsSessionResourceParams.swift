import Anthropic

/// Mount a file uploaded via the Files API into the session. Ported from
/// `beta_managed_agents_file_resource_params.py`. Also reused directly as the body of
/// `client.beta.sessions.resources.add` -- `sessions/resource_add_params.py` is byte-identical to
/// this type (confirmed via source comparison), so this port does not duplicate it as
/// `ResourceAddParams`.
public struct BetaManagedAgentsFileResourceParams: Encodable, Sendable, Equatable {
    public var fileId: String
    public var type = "file"
    public var mountPath: String?

    public init(fileId: String, mountPath: String? = nil) {
        self.fileId = fileId
        self.mountPath = mountPath
    }
}

/// Parameters for attaching a memory store to an agent session. Ported from
/// `beta_managed_agents_memory_store_resource_param.py`. `access` reuses the shared
/// `BetaManagedAgentsMemoryStoreAccess` enum (see `BetaManagedAgentsSessionResource.swift`).
public struct BetaManagedAgentsMemoryStoreResourceParam: Encodable, Sendable, Equatable {
    public var memoryStoreId: String
    public var type = "memory_store"
    public var access: BetaManagedAgentsMemoryStoreAccess?
    public var instructions: String?

    public init(
        memoryStoreId: String,
        access: BetaManagedAgentsMemoryStoreAccess? = nil,
        instructions: String? = nil
    ) {
        self.memoryStoreId = memoryStoreId
        self.access = access
        self.instructions = instructions
    }
}

/// A branch to check out in a mounted GitHub repository. Ported from
/// `beta_managed_agents_branch_checkout_param.py`.
public struct BetaManagedAgentsBranchCheckoutParam: Encodable, Sendable, Equatable {
    public var name: String
    public var type = "branch"

    public init(name: String) {
        self.name = name
    }
}

/// A commit to check out in a mounted GitHub repository. Ported from
/// `beta_managed_agents_commit_checkout_param.py`.
public struct BetaManagedAgentsCommitCheckoutParam: Encodable, Sendable, Equatable {
    public var sha: String
    public var type = "commit"

    public init(sha: String) {
        self.sha = sha
    }
}

/// Ported from the `Checkout` union local to
/// `beta_managed_agents_github_repository_resource_params.py` --
/// `Union[BetaManagedAgentsBranchCheckoutParam, BetaManagedAgentsCommitCheckoutParam]`. Request-only
/// (no `.unknown`); each leaf carries its own fixed `type` literal, so `encode(to:)` is a plain
/// switch.
public enum BetaManagedAgentsCheckoutParam: Sendable, Equatable {
    case branch(BetaManagedAgentsBranchCheckoutParam)
    case commit(BetaManagedAgentsCommitCheckoutParam)
}

extension BetaManagedAgentsCheckoutParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .branch(let value): try value.encode(to: encoder)
        case .commit(let value): try value.encode(to: encoder)
        }
    }
}

/// Mount a GitHub repository into the session's container. Ported from
/// `beta_managed_agents_github_repository_resource_params.py`.
public struct BetaManagedAgentsGitHubRepositoryResourceParams: Encodable, Sendable, Equatable {
    public var authorizationToken: String
    public var type = "github_repository"
    public var url: String
    public var checkout: BetaManagedAgentsCheckoutParam?
    public var mountPath: String?

    public init(
        authorizationToken: String,
        url: String,
        checkout: BetaManagedAgentsCheckoutParam? = nil,
        mountPath: String? = nil
    ) {
        self.authorizationToken = authorizationToken
        self.url = url
        self.checkout = checkout
        self.mountPath = mountPath
    }
}

/// Ported from the `Resource` union local to `session_create_params.py` --
/// `Union[BetaManagedAgentsGitHubRepositoryResourceParams, BetaManagedAgentsFileResourceParams, BetaManagedAgentsMemoryStoreResourceParam]`.
/// Request-only (no `.unknown`); each leaf carries its own fixed `type` literal, so `encode(to:)`
/// is a plain switch.
public enum BetaManagedAgentsSessionResourceParam: Sendable, Equatable {
    case githubRepository(BetaManagedAgentsGitHubRepositoryResourceParams)
    case file(BetaManagedAgentsFileResourceParams)
    case memoryStore(BetaManagedAgentsMemoryStoreResourceParam)
}

extension BetaManagedAgentsSessionResourceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .githubRepository(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        case .memoryStore(let value): try value.encode(to: encoder)
        }
    }
}
