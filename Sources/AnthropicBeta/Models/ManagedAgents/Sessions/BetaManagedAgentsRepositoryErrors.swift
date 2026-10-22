/// A repository mount failed because the credentials were rejected. Ported from
/// `sessions/beta_managed_agents_repository_authentication_error.py`.
public struct BetaManagedAgentsRepositoryAuthenticationError: Codable, Sendable, Equatable {
    public let message: String
    public let repositoryUrl: String?
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, repositoryUrl: String? = nil, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "repository_authentication_error"
    ) {
        self.message = message
        self.repositoryUrl = repositoryUrl
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// Access to the repository was forbidden. Ported from `..._repository_forbidden_error.py`.
public struct BetaManagedAgentsRepositoryForbiddenError: Codable, Sendable, Equatable {
    public let message: String
    public let repositoryUrl: String?
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, repositoryUrl: String? = nil, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "repository_forbidden_error"
    ) {
        self.message = message
        self.repositoryUrl = repositoryUrl
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// The repository doesn't exist (or isn't visible to the token). Ported from `..._repository_not_found_error.py`.
public struct BetaManagedAgentsRepositoryNotFoundError: Codable, Sendable, Equatable {
    public let message: String
    public let repositoryUrl: String?
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, repositoryUrl: String? = nil, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "repository_not_found_error"
    ) {
        self.message = message
        self.repositoryUrl = repositoryUrl
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// Checking out the requested branch or commit failed. Ported from `..._repository_checkout_error.py`.
public struct BetaManagedAgentsRepositoryCheckoutError: Codable, Sendable, Equatable {
    public let message: String
    public let repositoryUrl: String?
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, repositoryUrl: String? = nil, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "repository_checkout_error"
    ) {
        self.message = message
        self.repositoryUrl = repositoryUrl
        self.retryStatus = retryStatus
        self.type = type
    }
}

/// Cloning the repository failed. Ported from `..._repository_clone_error.py`.
public struct BetaManagedAgentsRepositoryCloneError: Codable, Sendable, Equatable {
    public let message: String
    public let repositoryUrl: String?
    public let retryStatus: BetaManagedAgentsRetryStatus
    public let type: String

    public init(
        message: String, repositoryUrl: String? = nil, retryStatus: BetaManagedAgentsRetryStatus,
        type: String = "repository_clone_error"
    ) {
        self.message = message
        self.repositoryUrl = repositoryUrl
        self.retryStatus = retryStatus
        self.type = type
    }
}
