import Foundation

public final class AnthropicClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!
    public static let defaultAnthropicVersion = "2023-06-01"

    let baseURL: URL
    let defaultHeaders: [String: String]
    let maxRetries: Int
    let timeout: TimeInterval
    let urlSession: URLSession
    let authProvider: any CredentialProvider

    /// - Parameters:
    ///   - apiKey: Falls back to the `ANTHROPIC_API_KEY`, then `ANTHROPIC_AUTH_TOKEN`, environment
    ///     variables when omitted.
    ///   - authProvider: Supply this instead of `apiKey` for non-API-key auth (added in Phase 5).
    ///
    /// This initializer never touches disk and never throws -- it only covers the two simplest
    /// credential sources (an explicit value, or one of two environment variables). For on-disk
    /// profiles or Workload Identity Federation, use ``resolvingCredentials(apiKey:authProvider:profile:baseURL:maxRetries:timeout:urlSession:identityTokenSource:)``.
    public init(
        apiKey: String? = nil,
        authProvider: (any CredentialProvider)? = nil,
        baseURL: URL = AnthropicClient.defaultBaseURL,
        maxRetries: Int = 2,
        timeout: TimeInterval = 600,
        urlSession: URLSession = .shared
    ) {
        let environment = ProcessInfo.processInfo.environment
        let resolvedKey = apiKey ?? environment["ANTHROPIC_API_KEY"]
        let resolvedAuthToken = environment["ANTHROPIC_AUTH_TOKEN"]
        self.baseURL = baseURL
        self.defaultHeaders = AnthropicClient.baseDefaultHeaders
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.urlSession = urlSession
        if let authProvider {
            self.authProvider = authProvider
        } else if let resolvedKey {
            self.authProvider = APIKeyProvider(apiKey: resolvedKey)
        } else if let resolvedAuthToken {
            self.authProvider = StaticTokenProvider(token: resolvedAuthToken)
        } else {
            self.authProvider = UnresolvedCredentialsProvider()
        }
    }

    /// Resolves credentials through the full precedence chain (explicit params, env vars, on-disk
    /// profiles, Workload Identity Federation) -- see `CredentialChain.resolve` for the exact order.
    /// Unlike the plain initializer, this can perform file I/O and network calls (a WIF token
    /// exchange, or a `user_oauth` refresh) and so can throw.
    public static func resolvingCredentials(
        apiKey: String? = nil,
        authProvider: (any CredentialProvider)? = nil,
        profile: String? = nil,
        baseURL: URL? = nil,
        maxRetries: Int = 2,
        timeout: TimeInterval = 600,
        urlSession: URLSession = .shared,
        identityTokenSource: (any IdentityTokenSource)? = nil
    ) async throws -> AnthropicClient {
        let environment = ProcessInfo.processInfo.environment
        let resolution = try await CredentialChain.resolve(
            apiKey: apiKey, authProvider: authProvider, profile: profile, baseURL: baseURL,
            environment: environment, urlSession: urlSession, identityTokenSource: identityTokenSource
        )
        let envBaseURL = environment["ANTHROPIC_BASE_URL"].flatMap { URL(string: $0) }
        let resolvedBaseURL = baseURL ?? envBaseURL ?? resolution.baseURL ?? AnthropicClient.defaultBaseURL
        return AnthropicClient(
            baseURL: resolvedBaseURL,
            defaultHeaders: AnthropicClient.baseDefaultHeaders,
            maxRetries: maxRetries,
            timeout: timeout,
            urlSession: urlSession,
            authProvider: resolution.provider
        )
    }

    private static let baseDefaultHeaders: [String: String] = [
        "anthropic-version": AnthropicClient.defaultAnthropicVersion,
        "content-type": "application/json",
    ]

    private init(
        baseURL: URL,
        defaultHeaders: [String: String],
        maxRetries: Int,
        timeout: TimeInterval,
        urlSession: URLSession,
        authProvider: any CredentialProvider
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.urlSession = urlSession
        self.authProvider = authProvider
    }

    package var transport: HTTPTransport { HTTPTransport(client: self) }

    public var messages: Messages { Messages(client: self) }
    public var models: Models { Models(client: self) }
    public var files: Files { Files(client: self) }
    public var skills: Skills { Skills(client: self) }

    /// Returns a new client that layers these overrides on top of the current defaults for every
    /// subsequent call. A `nil` header value unsets a default header rather than being ignored.
    public func withOptions(
        headers: [String: String?] = [:],
        maxRetries: Int? = nil,
        timeout: TimeInterval? = nil
    ) -> AnthropicClient {
        var mergedHeaders = defaultHeaders
        for (key, value) in headers {
            if let value {
                mergedHeaders[key] = value
            } else {
                mergedHeaders.removeValue(forKey: key)
            }
        }
        return AnthropicClient(
            baseURL: baseURL,
            defaultHeaders: mergedHeaders,
            maxRetries: maxRetries ?? self.maxRetries,
            timeout: timeout ?? self.timeout,
            urlSession: urlSession,
            authProvider: authProvider
        )
    }
}

/// Fallback `authProvider` when `AnthropicClient.init` finds no apiKey, authProvider, or credential
/// environment variable. The plain initializer is documented as never throwing, so the failure is
/// deferred to the first request instead of crashing the process via `precondition`.
private struct UnresolvedCredentialsProvider: CredentialProvider {
    func authHeader() async throws -> (name: String, value: String) {
        throw AnthropicError.authentication(APIErrorDetail(
            statusCode: nil,
            requestID: nil,
            workspaceID: nil,
            type: nil,
            message: "AnthropicClient needs an apiKey, an authProvider, an ANTHROPIC_API_KEY " +
                "environment variable, or an ANTHROPIC_AUTH_TOKEN environment variable.",
            body: nil,
            retryAfter: nil
        ))
    }

    func invalidate() async {}
}
