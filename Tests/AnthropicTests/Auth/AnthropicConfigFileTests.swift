import XCTest
@testable import Anthropic

final class AnthropicConfigFileTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anthropic-swift-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private var environment: [String: String] { ["ANTHROPIC_CONFIG_DIR": tempDir.path] }

    private func writeConfig(_ json: String, profile: String = "default") throws {
        let path = tempDir.appendingPathComponent("configs/\(profile).json")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: path)
    }

    func testLoadReturnsNilWhenFileIsMissing() throws {
        XCTAssertNil(try AnthropicConfigFile.load(profile: "default", environment: environment))
    }

    func testLoadThrowsWhenFileIsNotAJSONObject() throws {
        try writeConfig("not json")
        XCTAssertThrowsError(try AnthropicConfigFile.load(profile: "default", environment: environment))
    }

    func testLoadThrowsWhenAuthenticationIsMissing() throws {
        try writeConfig(#"{"organization_id":"org-1"}"#)
        XCTAssertThrowsError(try AnthropicConfigFile.load(profile: "default", environment: environment))
    }

    func testLoadThrowsOnUnrecognizedAuthenticationType() throws {
        try writeConfig(#"{"authentication":{"type":"something_else"}}"#)
        XCTAssertThrowsError(try AnthropicConfigFile.load(profile: "default", environment: environment))
    }

    func testLoadParsesMinimalUserOAuthProfile() throws {
        try writeConfig(#"{"authentication":{"type":"user_oauth","client_id":"client-1"}}"#)
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertEqual(config.authentication.type, .userOAuth)
        XCTAssertEqual(config.authentication.clientId, "client-1")
        XCTAssertNil(config.organizationId)
        XCTAssertNil(config.baseURL)
    }

    func testLoadParsesOidcFederationProfileWithFileIdentityToken() throws {
        try writeConfig(#"""
        {
            "authentication": {
                "type": "oidc_federation",
                "federation_rule_id": "rule-1",
                "service_account_id": "sa-1",
                "identity_token": {"source": "file", "path": "/etc/token"}
            },
            "organization_id": "org-1",
            "workspace_id": "ws-1",
            "base_url": "https://custom.anthropic.example"
        }
        """#)
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertEqual(config.authentication.type, .oidcFederation)
        XCTAssertEqual(config.authentication.federationRuleId, "rule-1")
        XCTAssertEqual(config.authentication.serviceAccountId, "sa-1")
        XCTAssertEqual(config.authentication.identityToken?.path, "/etc/token")
        XCTAssertEqual(config.organizationId, "org-1")
        XCTAssertEqual(config.workspaceId, "ws-1")
        XCTAssertEqual(config.baseURL, "https://custom.anthropic.example")
    }

    func testFileValuesWinOverEnvironmentBackfill() throws {
        try writeConfig(#"{"authentication":{"type":"oidc_federation","federation_rule_id":"file-rule"},"organization_id":"file-org"}"#)
        var environment = self.environment
        environment["ANTHROPIC_FEDERATION_RULE_ID"] = "env-rule"
        environment["ANTHROPIC_ORGANIZATION_ID"] = "env-org"
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertEqual(config.authentication.federationRuleId, "file-rule")
        XCTAssertEqual(config.organizationId, "file-org")
    }

    func testEnvironmentBackfillsFederationRuleIdOrganizationIdWorkspaceIdAndBaseURLWhenFileOmitsThem() throws {
        try writeConfig(#"{"authentication":{"type":"oidc_federation"}}"#)
        var environment = self.environment
        environment["ANTHROPIC_FEDERATION_RULE_ID"] = "env-rule"
        environment["ANTHROPIC_ORGANIZATION_ID"] = "env-org"
        environment["ANTHROPIC_WORKSPACE_ID"] = "env-ws"
        environment["ANTHROPIC_BASE_URL"] = "https://env.anthropic.example"
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertEqual(config.authentication.federationRuleId, "env-rule")
        XCTAssertEqual(config.organizationId, "env-org")
        XCTAssertEqual(config.workspaceId, "env-ws")
        XCTAssertEqual(config.baseURL, "https://env.anthropic.example")
    }

    func testIdentityTokenIsSynthesizedFromEnvFileVariableWhenFileHasNone() throws {
        try writeConfig(#"{"authentication":{"type":"oidc_federation","federation_rule_id":"rule-1"}}"#)
        var environment = self.environment
        environment["ANTHROPIC_IDENTITY_TOKEN_FILE"] = "/etc/env-token"
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertEqual(config.authentication.identityToken?.path, "/etc/env-token")
        XCTAssertEqual(config.authentication.identityToken?.source, "file")
    }

    func testLiteralIdentityTokenEnvVarIsNeverUsedToSynthesizeAFileSource() throws {
        try writeConfig(#"{"authentication":{"type":"oidc_federation","federation_rule_id":"rule-1"}}"#)
        var environment = self.environment
        environment["ANTHROPIC_IDENTITY_TOKEN"] = "literal-jwt-value"
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertNil(config.authentication.identityToken)
    }

    func testLoadThrowsWhenBaseURLIsPlainHTTP() throws {
        try writeConfig(#"{"authentication":{"type":"user_oauth","client_id":"client-1"},"base_url":"http://api.anthropic.com"}"#)
        XCTAssertThrowsError(try AnthropicConfigFile.load(profile: "default", environment: environment))
    }

    func testLoadDoesNotValidatePresenceOfFederationRuleIdOrOrganizationId() throws {
        // Absence is only enforced lazily at WIF-exchange time (`CredentialChain.loadProfile`), not
        // here -- a `user_oauth` profile has no use for either field.
        try writeConfig(#"{"authentication":{"type":"oidc_federation"}}"#)
        let config = try XCTUnwrap(try AnthropicConfigFile.load(profile: "default", environment: environment))
        XCTAssertNil(config.authentication.federationRuleId)
        XCTAssertNil(config.organizationId)
    }
}
