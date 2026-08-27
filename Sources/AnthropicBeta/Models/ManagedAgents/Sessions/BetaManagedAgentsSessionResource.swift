import Anthropic

/// Access mode for an attached memory store. Ported from the inline
/// `Optional[Literal["read_write", "read_only"]]` shared by
/// `beta_managed_agents_memory_store_resource.py` (response) and
/// `beta_managed_agents_memory_store_resource_param.py` (params) -- one `Codable` enum serves both
/// directions.
public enum BetaManagedAgentsMemoryStoreAccess: Sendable, Equatable {
    case readWrite
    case readOnly
    case unknown(String)
}

extension BetaManagedAgentsMemoryStoreAccess: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "read_write": self = .readWrite
        case "read_only": self = .readOnly
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .readWrite: try container.encode("read_write")
        case .readOnly: try container.encode("read_only")
        case .unknown(let value): try container.encode(value)
        }
    }
}

/// A file uploaded via the Files API and mounted into a session. Ported from
/// `beta_managed_agents_file_resource.py`.
public struct BetaManagedAgentsFileResource: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let fileId: String
    public let mountPath: String
    public let type: String
    public let updatedAt: String

    public init(
        id: String,
        createdAt: String,
        fileId: String,
        mountPath: String,
        type: String = "file",
        updatedAt: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fileId = fileId
        self.mountPath = mountPath
        self.type = type
        self.updatedAt = updatedAt
    }
}

/// A memory store attached to an agent session. Ported from
/// `beta_managed_agents_memory_store_resource.py`. `description`/`mountPath`/`name` are all
/// snapshotted at attach time -- later edits to the store don't propagate to this resource.
public struct BetaManagedAgentsMemoryStoreResource: Codable, Sendable, Equatable {
    public let memoryStoreId: String
    public let type: String
    public let access: BetaManagedAgentsMemoryStoreAccess?
    public let description: String?
    public let instructions: String?
    public let mountPath: String?
    public let name: String?

    public init(
        memoryStoreId: String,
        type: String = "memory_store",
        access: BetaManagedAgentsMemoryStoreAccess? = nil,
        description: String? = nil,
        instructions: String? = nil,
        mountPath: String? = nil,
        name: String? = nil
    ) {
        self.memoryStoreId = memoryStoreId
        self.type = type
        self.access = access
        self.description = description
        self.instructions = instructions
        self.mountPath = mountPath
        self.name = name
    }
}

/// A branch to check out in a mounted GitHub repository. Ported from
/// `beta_managed_agents_branch_checkout.py`.
public struct BetaManagedAgentsBranchCheckout: Codable, Sendable, Equatable {
    public let name: String
    public let type: String

    public init(name: String, type: String = "branch") {
        self.name = name
        self.type = type
    }
}

/// A commit to check out in a mounted GitHub repository. Ported from
/// `beta_managed_agents_commit_checkout.py`.
public struct BetaManagedAgentsCommitCheckout: Codable, Sendable, Equatable {
    public let sha: String
    public let type: String

    public init(sha: String, type: String = "commit") {
        self.sha = sha
        self.type = type
    }
}

/// Ported from the `Checkout` union local to `beta_managed_agents_github_repository_resource.py`
/// -- `Union[BetaManagedAgentsBranchCheckout, BetaManagedAgentsCommitCheckout, None]`,
/// discriminated on `type`. The `None` arm is just the field's own `Optional` wrapper in Python
/// (`checkout: Optional[Checkout]`), not a third case here.
public enum BetaManagedAgentsCheckout: Sendable, Equatable {
    case branch(BetaManagedAgentsBranchCheckout)
    case commit(BetaManagedAgentsCommitCheckout)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsCheckout: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "branch": self = .branch(try BetaManagedAgentsBranchCheckout(from: decoder))
        case "commit": self = .commit(try BetaManagedAgentsCommitCheckout(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .branch(let value): try value.encode(to: encoder)
        case .commit(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// A GitHub repository mounted into a session's container. Ported from
/// `beta_managed_agents_github_repository_resource.py`.
public struct BetaManagedAgentsGitHubRepositoryResource: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let mountPath: String
    public let type: String
    public let updatedAt: String
    public let url: String
    public let checkout: BetaManagedAgentsCheckout?

    public init(
        id: String,
        createdAt: String,
        mountPath: String,
        type: String = "github_repository",
        updatedAt: String,
        url: String,
        checkout: BetaManagedAgentsCheckout? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mountPath = mountPath
        self.type = type
        self.updatedAt = updatedAt
        self.url = url
        self.checkout = checkout
    }
}

/// Ported from `sessions/beta_managed_agents_session_resource.py` --
/// `Union[BetaManagedAgentsGitHubRepositoryResource, BetaManagedAgentsFileResource, BetaManagedAgentsMemoryStoreResource]`,
/// discriminated on `type`. Also reused directly as `ResourceRetrieveResponse`/
/// `ResourceUpdateResponse` (confirmed byte-identical unions in the Python source) -- this port
/// does not duplicate those as separate types.
public enum BetaManagedAgentsSessionResource: Sendable, Equatable {
    case githubRepository(BetaManagedAgentsGitHubRepositoryResource)
    case file(BetaManagedAgentsFileResource)
    case memoryStore(BetaManagedAgentsMemoryStoreResource)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionResource: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "github_repository":
            self = .githubRepository(try BetaManagedAgentsGitHubRepositoryResource(from: decoder))
        case "file":
            self = .file(try BetaManagedAgentsFileResource(from: decoder))
        case "memory_store":
            self = .memoryStore(try BetaManagedAgentsMemoryStoreResource(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .githubRepository(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        case .memoryStore(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Confirmation of resource deletion. Ported from
/// `sessions/beta_managed_agents_delete_session_resource.py`. Distinct from
/// `BetaManagedAgentsDeletedSession` (`type: "session_deleted"`) -- this is the resource-level
/// (not session-level) delete confirmation.
public struct BetaManagedAgentsDeleteSessionResource: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "session_resource_deleted") {
        self.id = id
        self.type = type
    }
}
