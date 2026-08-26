import XCTest
@testable import Anthropic

final class ProfileCredentialsProviderTests: XCTestCase {
    private var tempDir: URL!
    private let baseURL = URL(string: "https://api.anthropic.com")!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anthropic-swift-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        MockURLProtocol.responder = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private var environment: [String: String] { ["ANTHROPIC_CONFIG_DIR": tempDir.path] }

    private func makeProvider(workspaceId: String? = nil) -> ProfileCredentialsProvider {
        ProfileCredentialsProvider(
            profile: "default", environment: environment, clientId: "client-1",
            workspaceId: workspaceId, baseURL: baseURL, urlSession: MockURLProtocol.makeSession()
        )
    }

    func testAuthHeaderReturnsBearerTokenFromStoredCredentialsWithoutNetworkCall() async throws {
        try CredentialsStore.store(
            profile: "default", environment: environment, accessToken: "at-stored",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-stored"
        )
        MockURLProtocol.responder = { _ in
            XCTFail("no network call expected for a non-expired stored token")
            throw URLError(.badURL)
        }
        let header = try await makeProvider().authHeader()
        XCTAssertEqual(header.name, "authorization")
        XCTAssertEqual(header.value, "Bearer at-stored")
    }

    func testAuthHeaderThrowsWhenNoStoredCredentialsExist() async throws {
        do {
            _ = try await makeProvider().authHeader()
            XCTFail("expected an error when no credentials are stored")
        } catch {
            // expected
        }
    }

    func testAuthHeaderRefreshesAndPersistsWhenStoredCredentialIsExpired() async throws {
        try CredentialsStore.store(
            profile: "default", environment: environment, accessToken: "at-old",
            expiresAt: Date().addingTimeInterval(10), refreshToken: "rt-old"
        )
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-new","expires_in":3600,"refresh_token":"rt-new"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let header = try await makeProvider().authHeader()
        XCTAssertEqual(header.value, "Bearer at-new")

        let stored = try XCTUnwrap(try CredentialsStore.read(profile: "default", environment: environment))
        XCTAssertEqual(stored.accessToken, "at-new")
        XCTAssertEqual(stored.refreshToken, "rt-new")
    }

    func testAuthHeaderThrowsWhenExpiredWithNoRefreshToken() async throws {
        try CredentialsStore.store(
            profile: "default", environment: environment, accessToken: "at-old",
            expiresAt: Date().addingTimeInterval(10), refreshToken: nil
        )
        do {
            _ = try await makeProvider().authHeader()
            XCTFail("expected an error when expired with no refresh_token")
        } catch {
            // expected
        }
    }

    func testExtraHeadersIncludesWorkspaceIdOnlyWhenConfigured() async throws {
        let headers = try await makeProvider(workspaceId: "ws-1").extraHeaders()
        XCTAssertEqual(headers["anthropic-workspace-id"], "ws-1")
        XCTAssertEqual(headers["anthropic-beta"], OAuthTokenEndpoint.oauthBetaHeader)

        let headersNoWorkspace = try await makeProvider(workspaceId: nil).extraHeaders()
        XCTAssertNil(headersNoWorkspace["anthropic-workspace-id"])
    }

    func testInvalidatePicksUpCredentialsRotatedOnDiskByAnotherProcess() async throws {
        try CredentialsStore.store(
            profile: "default", environment: environment, accessToken: "at-first",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-first"
        )
        let provider = makeProvider()
        let firstHeader = try await provider.authHeader()
        XCTAssertEqual(firstHeader.value, "Bearer at-first")

        try CredentialsStore.store(
            profile: "default", environment: environment, accessToken: "at-rotated",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-rotated"
        )
        await provider.invalidate()
        let secondHeader = try await provider.authHeader()
        XCTAssertEqual(secondHeader.value, "Bearer at-rotated")
    }
}

final class WorkloadIdentityCredentialsTests: XCTestCase {
    private let baseURL = URL(string: "https://api.anthropic.com")!

    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private func makeProvider(
        workspaceId: String? = nil, identityTokenSource: any IdentityTokenSource
    ) -> WorkloadIdentityCredentials {
        WorkloadIdentityCredentials(
            baseURL: baseURL, federationRuleId: "rule-1", organizationId: "org-1",
            serviceAccountId: "sa-1", workspaceId: workspaceId, identityTokenSource: identityTokenSource,
            urlSession: MockURLProtocol.makeSession()
        )
    }

    func testAuthHeaderExchangesIdentityTokenForBearerToken() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            let body = Data(#"{"access_token":"at-wif","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let source = CountingIdentityTokenSource(value: "assertion-jwt")
        let header = try await makeProvider(identityTokenSource: source).authHeader()
        XCTAssertEqual(header.name, "authorization")
        XCTAssertEqual(header.value, "Bearer at-wif")
        let callCount = await source.callCount
        XCTAssertEqual(callCount, 1)

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["assertion"] as? String, "assertion-jwt")
        XCTAssertEqual(json["federation_rule_id"] as? String, "rule-1")
        XCTAssertEqual(json["organization_id"] as? String, "org-1")
        XCTAssertEqual(json["service_account_id"] as? String, "sa-1")
    }

    func testExtraHeadersNeverIncludesWorkspaceIdEvenWhenConfigured() async throws {
        let source = CountingIdentityTokenSource(value: "assertion-jwt")
        let headers = try await makeProvider(workspaceId: "ws-1", identityTokenSource: source).extraHeaders()
        XCTAssertNil(headers["anthropic-workspace-id"])
        XCTAssertEqual(headers["anthropic-beta"], OAuthTokenEndpoint.oauthBetaHeader)
    }

    func testFreshTokenIsServedFromCacheWithoutRequestingANewIdentityToken() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-wif","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let source = CountingIdentityTokenSource(value: "assertion-jwt")
        let provider = makeProvider(identityTokenSource: source)
        _ = try await provider.authHeader()
        _ = try await provider.authHeader()
        let callCount = await source.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testInvalidateForcesANewIdentityTokenExchange() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-wif","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let source = CountingIdentityTokenSource(value: "assertion-jwt")
        let provider = makeProvider(identityTokenSource: source)
        _ = try await provider.authHeader()
        await provider.invalidate()
        _ = try await provider.authHeader()
        let callCount = await source.callCount
        XCTAssertEqual(callCount, 2)
    }
}

private actor CountingIdentityTokenSource: IdentityTokenSource {
    private(set) var callCount = 0
    private let value: String

    init(value: String) {
        self.value = value
    }

    func token() async throws -> String {
        callCount += 1
        return value
    }
}
