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
        // Explicit, not umask-derived: the loader refuses group/other-writable config files.
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
    }

    // MARK: - explicit authProvider / apiKey

    func testExplicitAuthProviderIsUsedAndTheEnvironmentIsNotConsulted() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: StaticTokenProvider(token: "explicit"), profile: nil,
            baseURL: nil, environment: ["ANTHROPIC_API_KEY": "env-key"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer explicit")
        XCTAssertNil(resolution.baseURL)
    }

    // A client has one credential: two explicit ones used to be settled silently by precedence, which
    // hid a stale argument left in place. Each pair, and all three, must now be refused up front.
    func testMoreThanOneExplicitCredentialIsRefused() async throws {
        let provider = StaticTokenProvider(token: "explicit")
        let cases: [(String?, (any CredentialProvider)?, String?, [String])] = [
            ("key", provider, nil, ["apiKey", "authProvider"]),
            ("key", nil, "work", ["apiKey", "profile"]),
            (nil, provider, "work", ["authProvider", "profile"]),
            ("key", provider, "work", ["apiKey", "authProvider", "profile"]),
        ]
        for (apiKey, authProvider, profile, named) in cases {
            do {
                _ = try await CredentialChain.resolve(
                    apiKey: apiKey, authProvider: authProvider, profile: profile, baseURL: nil,
                    environment: [:], urlSession: MockURLProtocol.makeSession()
                )
                XCTFail("expected \(named) together to be refused")
            } catch AnthropicError.invalidArgument(let message) {
                for name in named {
                    XCTAssertTrue(message.contains(name), "\(message) should name \(name)")
                }
                XCTAssertTrue(message.contains("at most one"), message)
            } catch {
                XCTFail("expected .invalidArgument for \(named), got \(error)")
            }
        }
    }

    func testExplicitApiKeyTakesPrecedenceOverEnvironmentApiKey() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: "explicit-key", authProvider: nil, profile: nil, baseURL: nil,
            environment: ["ANTHROPIC_API_KEY": "env-key"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.name, "authorization")
        XCTAssertEqual(header.value, "Bearer explicit-key")
        XCTAssertNil(resolution.baseURL)
    }

    // MARK: - environment credentials

    func testEnvironmentApiKeyUsedWhenNoProfileRequested() async throws {
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: ["ANTHROPIC_API_KEY": "env-key"], urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.name, "authorization")
        XCTAssertEqual(header.value, "Bearer env-key")
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

    // MARK: - explicit profile selection (hard failure on error)

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

    func testSettingConfigDirAloneMakesAMissingActiveProfileAHardError() async throws {
        // `ANTHROPIC_CONFIG_DIR` selects no profile, but once resolution reaches the active-profile step
        // a user-configured location must demand a real "default" profile rather than fall through to
        // the best-effort passive discovery, whose `try?` swallows errors. (There is deliberately no
        // test of that passive branch: it reads the real home directory, which no environment-dict
        // override can sandbox.)
        do {
            _ = try await CredentialChain.resolve(
                apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
                environment: environment, urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected a hard failure resolving the implied \"default\" profile")
        } catch let error as AnthropicError {
            XCTAssertTrue(error.isCredentialsError, "\(error)")
        }
    }

    func testActiveProfileInAConfiguredDirectoryIsUsed() async throws {
        try writeUserOAuthProfile(named: "default")
        try CredentialsStore.store(
            profile: "default", environment: environment, accessToken: "at-default",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt"
        )
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-default")
    }

    func testActiveConfigPointerSelectsTheActiveProfile() async throws {
        try writeUserOAuthProfile(named: "work")
        try CredentialsStore.store(
            profile: "work", environment: environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt"
        )
        try Data("work\n".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-work")
    }

    // MARK: - Workload Identity Federation via pure env vars

    func testWorkloadIdentityFederationViaPureEnvironmentVariables() async throws {
        let tokenFile = tempDir.appendingPathComponent("identity-token")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("assertion-jwt".utf8).write(to: tokenFile)

        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-wif","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        // Hermetic now that workload identity outranks the config directory and the active profile:
        // ANTHROPIC_CONFIG_DIR can point at an empty directory without diverting resolution.
        var environment = self.environment
        environment.merge([
            "ANTHROPIC_FEDERATION_RULE_ID": "rule-1",
            "ANTHROPIC_ORGANIZATION_ID": "org-1",
            "ANTHROPIC_IDENTITY_TOKEN_FILE": tokenFile.path,
        ]) { _, new in new }
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        let header = try await resolution.provider.authHeader()
        XCTAssertEqual(header.value, "Bearer at-wif")
    }

    /// Writes an identity token file, stubs the token endpoint to answer `at-wif`, and returns the
    /// federation variables (without choosing any config directory).
    private func workloadIdentityEnvironment(extra: [String: String] = [:]) throws -> [String: String] {
        let tokenFile = tempDir.appendingPathComponent("identity-token")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("assertion-jwt".utf8).write(to: tokenFile)
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-wif","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        return [
            "ANTHROPIC_FEDERATION_RULE_ID": "rule-1",
            "ANTHROPIC_ORGANIZATION_ID": "org-1",
            "ANTHROPIC_IDENTITY_TOKEN_FILE": tokenFile.path,
        ].merging(extra) { _, new in new }
    }

    private func resolveBearer(_ environment: [String: String]) async throws -> String {
        let resolution = try await CredentialChain.resolve(
            apiKey: nil, authProvider: nil, profile: nil, baseURL: nil,
            environment: environment, urlSession: MockURLProtocol.makeSession()
        )
        return try await resolution.provider.authHeader().value
    }

    // MARK: - workload identity outranks the active profile, not an explicitly named one

    func testWorkloadIdentityBeatsAConfigDirWithNoUsableProfile() async throws {
        // The config directory only says where profiles live. It used to count as explicit profile
        // selection, so this setup failed on the missing "default" profile despite valid federation.
        let environment = try workloadIdentityEnvironment(extra: ["ANTHROPIC_CONFIG_DIR": tempDir.path])
        let bearer = try await resolveBearer(environment)
        XCTAssertEqual(bearer, "Bearer at-wif")
    }

    func testWorkloadIdentityBeatsTheActiveConfigPointer() async throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("missing-profile".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let environment = try workloadIdentityEnvironment(extra: ["ANTHROPIC_CONFIG_DIR": tempDir.path])
        let bearer = try await resolveBearer(environment)
        XCTAssertEqual(bearer, "Bearer at-wif", "a pointer to a profile that does not exist must not be read")
    }

    func testProfileNamedInTheEnvironmentBeatsWorkloadIdentity() async throws {
        try writeUserOAuthProfile(named: "work")
        try CredentialsStore.store(
            profile: "work", environment: self.environment, accessToken: "at-work",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt"
        )
        let environment = try workloadIdentityEnvironment(extra: [
            "ANTHROPIC_CONFIG_DIR": tempDir.path, "ANTHROPIC_PROFILE": "work",
        ])
        let bearer = try await resolveBearer(environment)
        XCTAssertEqual(bearer, "Bearer at-work")
    }

    func testEmptyIdentityTokenDoesNotCountAsWorkloadIdentity() async throws {
        // A CI variable that is defined but empty is "not set". With nothing else to go on, federation
        // must not be selected over the active profile.
        try writeUserOAuthProfile(named: "default")
        try CredentialsStore.store(
            profile: "default", environment: self.environment, accessToken: "at-default",
            expiresAt: Date().addingTimeInterval(500), refreshToken: "rt"
        )
        var environment = self.environment
        environment["ANTHROPIC_FEDERATION_RULE_ID"] = "rule-1"
        environment["ANTHROPIC_ORGANIZATION_ID"] = "org-1"
        environment["ANTHROPIC_IDENTITY_TOKEN"] = ""
        let bearer = try await resolveBearer(environment)
        XCTAssertEqual(bearer, "Bearer at-default")
    }

    func testAnAlreadyConfiguredBrokenActiveProfileStillRaisesWhenWorkloadIdentityIsNotSet() async throws {
        // Federation variables incomplete (no identity token): falls to the active profile, which the
        // user configured by setting the directory, so its absence is an error rather than a fallthrough.
        var environment = self.environment
        environment["ANTHROPIC_FEDERATION_RULE_ID"] = "rule-1"
        environment["ANTHROPIC_ORGANIZATION_ID"] = "org-1"
        do {
            _ = try await resolveBearer(environment)
            XCTFail("expected a credentials error")
        } catch let error as AnthropicError {
            XCTAssertTrue(error.isCredentialsError, "\(error)")
        }
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
