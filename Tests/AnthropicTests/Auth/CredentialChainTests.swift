import XCTest
@testable import Anthropic

final class CredentialChainTests: XCTestCase {
    private var tempDir: URL!

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

    private func writeUserOAuthProfile(
        named profile: String, clientId: String = "client-1", baseURL: String? = nil
    ) throws {
        let path = tempDir.appendingPathComponent("configs/\(profile).json")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        var object: [String: Any] = ["authentication": ["type": "user_oauth", "client_id": clientId]]
        if let baseURL { object["base_url"] = baseURL }
        try JSONSerialization.data(withJSONObject: object).write(to: path)
    }

    // MARK: - step 1 / 2: explicit authProvider / apiKey

    func testExplicitAuthProviderTakesPrecedenceOverEverythingElse() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: "should-be-ignored", authProvider: StaticTokenProvider(token: "explicit"), profile: nil,
            baseURL: nil, environment: ["ANTHROPIC_API_KEY": "env-key"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer explicit")
        XCTAssertNil(resolution.baseURL)
    }

    func testExplicitApiKeyTakesPrecedenceOverEnvironmentApiKey() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: "explicit-key", authProvider: nil, profile: nil, baseURL: nil,
            environment: ["ANTHROPIC_API_KEY": "env-key"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.name, "x-api-key")
        XCTAssertEqual(header.value, "explicit-key")
        XCTAssertNil(resolution.baseURL)
    }

    // MARK: - step 3: env vars, only when no profile requested

    func testEnvironmentApiKeyUsedWhenNoProfileRequested() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: ["ANTHROPIC_API_KEY": "env-key"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.name, "x-api-key")
        XCTAssertEqual(header.value, "env-key")
    }

    func testEnvironmentAuthTokenUsedWhenNoApiKeyIsSet() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: ["ANTHROPIC_AUTH_TOKEN": "env-token"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.name, "authorization")
        XCTAssertEqual(header.value, "Bearer env-token")
    }

    func testEnvironmentApiKeyIsIgnoredWhenAProfileIsExplicitlyRequested() async throws {
        try writeUserOAuthProfile(named: "work")
        try CredentialsStore.store(
            profile: "work", environment: environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-work"
        )
        var environment = self.environment
        environment["ANTHROPIC_API_KEY"] = "env-key"

        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: "work", baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-work")
    }

    // MARK: - step 4: explicit profile selection (hard failure on error)

    func testExplicitProfileParamResolvesStoredCredentials() async throws {
        try writeUserOAuthProfile(named: "work")
        try CredentialsStore.store(
            profile: "work", environment: environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-work"
        )
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: "work", baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-work")
    }

    func testExplicitProfileViaEnvironmentVariableIsAlsoHonored() async throws {
        try writeUserOAuthProfile(named: "work")
        try CredentialsStore.store(
            profile: "work", environment: environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-work"
        )
        var environment = self.environment
        environment["ANTHROPIC_PROFILE"] = "work"

        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-work")
    }

    func testExplicitProfileSelectionHardFailsWhenTheProfileHasNoConfigFile() async throws {
        do {
            _ = try await CredentialChain.resolve(
                apiKey: nil, authProvider: nil, profile: "missing", baseURL: nil,
                environment: environment, urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("an explicitly requested profile with no config file must be a hard error")
        } catch {
            // expected
        }
    }

    func testSettingConfigDirAloneCountsAsExplicitProfileSelection() async throws {
        // Setting ANTHROPIC_CONFIG_DIR (with no ANTHROPIC_PROFILE and no `profile` param) makes
        // `ProfilePaths.hasExplicitActiveConfig` return true, which routes resolution through step 4
        // (explicit selection, hard failure) against the implied "default" profile -- NOT through
        // step 6's `try?`-swallowed passive fallback. There is deliberately no dedicated test of step
        // 6 itself: it can only be reached when nothing overrides `configDirectory`'s fallback to the
        // real `FileManager.default.homeDirectoryForCurrentUser`, which no environment-dict override
        // can sandbox, so exercising it hermetically isn't possible. This test instead locks down the
        // (subtle, easy to get wrong) fact that a bare ANTHROPIC_CONFIG_DIR is enough to disable that
        // passive fallback and demand a real "default" profile.
        do {
            _ = try await CredentialChain.resolve(
                apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
                environment: environment, urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected a hard failure resolving the implied \"default\" profile")
        } catch {
            // expected
        }
    }

    // MARK: - step 5: Workload Identity Federation via pure env vars

    func testWorkloadIdentityFederationViaPureEnvironmentVariables() async throws {
        let tokenFile = tempDir.appendingPathComponent("identity-token")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("assertion-jwt".utf8).write(to: tokenFile)

        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-wif","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        // Deliberately does NOT set ANTHROPIC_CONFIG_DIR/ANTHROPIC_PROFILE (either would flip
        // `hasExplicitActiveConfig` to true and divert resolution into step 4 instead of step 5).
        // This makes the test rely on the real machine having no pre-existing
        // ~/.config/anthropic/active_config pointer file, since there is no environment-dict
        // override for that fallback -- an accepted, documented non-hermetic assumption.
        let environment = [
            "ANTHROPIC_FEDERATION_RULE_ID": "rule-1",
            "ANTHROPIC_ORGANIZATION_ID": "org-1",
            "ANTHROPIC_IDENTITY_TOKEN_FILE": tokenFile.path,
        ]
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-wif")
    }

    // MARK: - resolution.baseURL

    func testResolutionBaseURLReflectsTheProfilesOwnConfigValueRegardlessOfExplicitOverride() async throws {
        try writeUserOAuthProfile(named: "work", baseURL: "https://profile.anthropic.example")
        try CredentialsStore.store(
            profile: "work", environment: environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-work"
        )
        // `resolution.baseURL` always carries the profile's own declared base_url -- it is not
        // affected by an explicit `baseURL` override, which only changes which server the
        // provider's own token-refresh requests hit. `AnthropicClient.resolvingCredentials` applies
        // the explicit override with higher precedence than `resolution.baseURL` on its own.
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: "work",
            baseURL: URL(string: "https://explicit.anthropic.example"),
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        XCTAssertEqual(resolution.baseURL?.absoluteString, "https://profile.anthropic.example")
    }

    func testResolutionBaseURLIsNilWhenProfileHasNoBaseURL() async throws {
        try writeUserOAuthProfile(named: "work")
        try CredentialsStore.store(
            profile: "work", environment: environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt-work"
        )
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: "work", baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        XCTAssertNil(resolution.baseURL)
    }
}
