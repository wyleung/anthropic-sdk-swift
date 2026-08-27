import Anthropic

/// A file uploaded via the Files API, echoed back on a deployment. Leaner than the session-side
/// `BetaManagedAgentsFileResource` -- no `id`/`createdAt`/`updatedAt`, since a deployment's
/// resource config isn't itself a lifecycle object. Ported from
/// `beta_managed_agents_file_resource_config.py`.
public struct BetaManagedAgentsFileResourceConfig: Codable, Sendable, Equatable {
    public let fileId: String
    public let type: String
    public let mountPath: String?

    public init(fileId: String, type: String = "file", mountPath: String? = nil) {
        self.fileId = fileId
        self.type = type
        self.mountPath = mountPath
    }
}

/// A memory store attached to sessions created from a deployment. Leaner than the session-side
/// `BetaManagedAgentsMemoryStoreResource` -- drops the attach-time `description`/`mountPath`/
/// `name` snapshot. Ported from `beta_managed_agents_memory_store_resource_config.py`. Reuses
/// `BetaManagedAgentsMemoryStoreAccess` from `BetaManagedAgentsSessionResource.swift`.
public struct BetaManagedAgentsMemoryStoreResourceConfig: Codable, Sendable, Equatable {
    public let memoryStoreId: String
    public let type: String
    public let access: BetaManagedAgentsMemoryStoreAccess?
    public let instructions: String?

    public init(
        memoryStoreId: String,
        type: String = "memory_store",
        access: BetaManagedAgentsMemoryStoreAccess? = nil,
        instructions: String? = nil
    ) {
        self.memoryStoreId = memoryStoreId
        self.type = type
        self.access = access
        self.instructions = instructions
    }
}

/// A GitHub repository mounted into sessions created from a deployment. Leaner than the
/// session-side `BetaManagedAgentsGitHubRepositoryResource` -- no `id`/`createdAt`/`updatedAt`;
/// the authorization token is write-only and never returned. Ported from
/// `beta_managed_agents_github_repository_resource_config.py`. Reuses the existing
/// `BetaManagedAgentsCheckout` union (and its `BetaManagedAgentsBranchCheckout`/
/// `BetaManagedAgentsCommitCheckout` leaves) from `BetaManagedAgentsSessionResource.swift` --
/// `Checkout` there imports from the identical top-level Python modules as this config type.
public struct BetaManagedAgentsGitHubRepositoryResourceConfig: Codable, Sendable, Equatable {
    public let type: String
    public let url: String
    public let checkout: BetaManagedAgentsCheckout?
    public let mountPath: String?

    public init(
        type: String = "github_repository",
        url: String,
        checkout: BetaManagedAgentsCheckout? = nil,
        mountPath: String? = nil
    ) {
        self.type = type
        self.url = url
        self.checkout = checkout
        self.mountPath = mountPath
    }
}

/// Ported from `beta_managed_agents_session_resource_config.py` --
/// `Union[BetaManagedAgentsGitHubRepositoryResourceConfig, BetaManagedAgentsFileResourceConfig, BetaManagedAgentsMemoryStoreResourceConfig]`,
/// discriminated on `type`. A distinct wrapper from `BetaManagedAgentsSessionResource` (which
/// wraps the full-lifecycle session-side types) even though the two share leaf-type naming
/// conventions.
public enum BetaManagedAgentsSessionResourceConfig: Sendable, Equatable {
    case githubRepository(BetaManagedAgentsGitHubRepositoryResourceConfig)
    case file(BetaManagedAgentsFileResourceConfig)
    case memoryStore(BetaManagedAgentsMemoryStoreResourceConfig)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsSessionResourceConfig: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "github_repository":
            self = .githubRepository(try BetaManagedAgentsGitHubRepositoryResourceConfig(from: decoder))
        case "file":
            self = .file(try BetaManagedAgentsFileResourceConfig(from: decoder))
        case "memory_store":
            self = .memoryStore(try BetaManagedAgentsMemoryStoreResourceConfig(from: decoder))
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
