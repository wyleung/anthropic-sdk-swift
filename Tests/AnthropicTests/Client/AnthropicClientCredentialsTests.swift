import XCTest
@testable import Anthropic
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Regression coverage for the fix to `AnthropicClient.init`: with no `apiKey`, no `authProvider`,
/// and no credential environment variable, the plain (documented-as-non-throwing) initializer must
/// still succeed rather than crashing via `precondition` -- the failure is deferred to a normal,
/// catchable `AnthropicError.authentication` thrown on the first request.
final class AnthropicClientCredentialsTests: XCTestCase {
    private var savedAPIKey: String?
    private var savedAuthToken: String?

    override func setUp() {
        super.setUp()
        savedAPIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        savedAuthToken = ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"]
        unsetenv("ANTHROPIC_API_KEY")
        unsetenv("ANTHROPIC_AUTH_TOKEN")
    }

    override func tearDown() {
        if let savedAPIKey {
            setenv("ANTHROPIC_API_KEY", savedAPIKey, 1)
        } else {
            unsetenv("ANTHROPIC_API_KEY")
        }
        if let savedAuthToken {
            setenv("ANTHROPIC_AUTH_TOKEN", savedAuthToken, 1)
        } else {
            unsetenv("ANTHROPIC_AUTH_TOKEN")
        }
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    func testInitWithNoCredentialsSucceedsRatherThanCrashing() {
        // The historical bug was a `precondition` trap here -- simply not crashing is the assertion.
        _ = AnthropicClient()
    }

    func testFirstRequestWithNoCredentialsThrowsACatchableAuthenticationError() async throws {
        MockURLProtocol.responder = { _ in
            XCTFail("should never reach the network with unresolved credentials")
            throw URLError(.unknown)
        }
        let client = AnthropicClient(urlSession: MockURLProtocol.makeSession())

        do {
            _ = try await client.models.retrieve("claude-opus-5")
            XCTFail("expected an authentication error")
        } catch AnthropicError.authentication(let detail) {
            XCTAssertTrue(detail.message.contains("apiKey"))
        }
    }

    // MARK: - one credential per client

    /// The `Authorization` header the client sends on one request (the response is a stub; only what
    /// went out matters).
    private func authorizationSent(by client: AnthropicClient) async -> String? {
        var sent: String?
        MockURLProtocol.responder = { request in
            sent = request.value(forHTTPHeaderField: "authorization")
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data("{}".utf8))
        }
        _ = try? await client.models.retrieve("claude-opus-5")
        return sent
    }

    func testPassingBothAnApiKeyAndAnAuthProviderIsRefusedOnTheFirstRequest() async throws {
        MockURLProtocol.responder = { _ in
            XCTFail("a conflicting credential must never reach the network")
            throw URLError(.unknown)
        }
        let client = AnthropicClient(
            apiKey: "key", authProvider: StaticTokenProvider(token: "token"), urlSession: MockURLProtocol.makeSession()
        )

        do {
            _ = try await client.models.retrieve("claude-opus-5")
            XCTFail("expected the conflicting credentials to be refused")
        } catch AnthropicError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("at most one"), message)
            XCTAssertTrue(message.contains("apiKey") && message.contains("authProvider"), message)
        }
    }

    func testAnEmptyEnvironmentVariableIsTreatedAsUnset() async {
        setenv("ANTHROPIC_API_KEY", "", 1)
        setenv("ANTHROPIC_AUTH_TOKEN", "env-token", 1)

        let sent = await authorizationSent(by: AnthropicClient(urlSession: MockURLProtocol.makeSession()))

        XCTAssertEqual(sent, "Bearer env-token", "an empty API key must not shadow the auth token")
    }

    func testTheApiKeyIsUsedWhenBothEnvironmentVariablesAreSet() async {
        setenv("ANTHROPIC_API_KEY", "env-key", 1)
        setenv("ANTHROPIC_AUTH_TOKEN", "env-token", 1)

        let sent = await authorizationSent(by: AnthropicClient(urlSession: MockURLProtocol.makeSession()))

        XCTAssertEqual(sent, "Bearer env-key")
    }

    func testAnExplicitCredentialMeansTheEnvironmentIsNotConsulted() async {
        setenv("ANTHROPIC_API_KEY", "env-key", 1)

        let sent = await authorizationSent(
            by: AnthropicClient(authProvider: StaticTokenProvider(token: "explicit"), urlSession: MockURLProtocol.makeSession())
        )

        XCTAssertEqual(sent, "Bearer explicit")
    }
}
