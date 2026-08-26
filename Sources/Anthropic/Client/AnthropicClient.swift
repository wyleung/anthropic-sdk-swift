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
    ///   - apiKey: Falls back to the `ANTHROPIC_API_KEY` environment variable when omitted.
    ///   - authProvider: Supply this instead of `apiKey` for non-API-key auth (added in Phase 5).
    public init(
        apiKey: String? = nil,
        authProvider: (any CredentialProvider)? = nil,
        baseURL: URL = AnthropicClient.defaultBaseURL,
        maxRetries: Int = 2,
        timeout: TimeInterval = 600,
        urlSession: URLSession = .shared
    ) {
        let resolvedKey = apiKey ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        precondition(
            authProvider != nil || resolvedKey != nil,
            "AnthropicClient needs an apiKey, an authProvider, or an ANTHROPIC_API_KEY environment variable."
        )
        self.baseURL = baseURL
        self.defaultHeaders = [
            "anthropic-version": AnthropicClient.defaultAnthropicVersion,
            "content-type": "application/json",
        ]
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.urlSession = urlSession
        self.authProvider = authProvider ?? APIKeyProvider(apiKey: resolvedKey!)
    }

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

    var transport: HTTPTransport { HTTPTransport(client: self) }

    public var messages: Messages { Messages(client: self) }

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
