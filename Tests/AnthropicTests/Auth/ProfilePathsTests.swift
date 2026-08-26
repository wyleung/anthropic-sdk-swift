import XCTest
@testable import Anthropic

final class ProfilePathsTests: XCTestCase {
    // MARK: - validateProfileName

    func testValidateProfileNameAcceptsAnOrdinaryName() throws {
        XCTAssertEqual(try ProfilePaths.validateProfileName("work"), "work")
    }

    func testValidateProfileNameRejectsEmpty() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName(""))
    }

    func testValidateProfileNameRejectsLeadingWhitespace() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName(" work"))
    }

    func testValidateProfileNameRejectsTrailingWhitespace() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName("work "))
    }

    func testValidateProfileNameRejectsLeadingDot() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName(".work"))
        XCTAssertThrowsError(try ProfilePaths.validateProfileName(".."))
    }

    func testValidateProfileNameRejectsForwardSlash() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName("a/b"))
    }

    func testValidateProfileNameRejectsBackslash() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName("a\\b"))
    }

    func testValidateProfileNameRejectsNUL() {
        XCTAssertThrowsError(try ProfilePaths.validateProfileName("a\0b"))
    }

    // MARK: - activeProfile precedence

    func testActiveProfileDefaultsWhenNothingIsSet() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        XCTAssertEqual(try ProfilePaths.activeProfile(environment: environment), "default")
    }

    func testActiveProfilePrefersEnvVarOverPointerFile() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("from-pointer".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path, "ANTHROPIC_PROFILE": "from-env"]
        XCTAssertEqual(try ProfilePaths.activeProfile(environment: environment), "from-env")
    }

    func testActiveProfileFallsBackToPointerFile() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("  from-pointer  \n".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        XCTAssertEqual(try ProfilePaths.activeProfile(environment: environment), "from-pointer")
    }

    func testActiveProfileTreatsAnEmptyPointerFileAsUnset() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("   \n".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        XCTAssertEqual(try ProfilePaths.activeProfile(environment: environment), "default")
    }

    // MARK: - hasExplicitActiveConfig

    func testHasExplicitActiveConfigIsFalseWithNothingSet() {
        // `ANTHROPIC_CONFIG_DIR` itself counts as explicit (see
        // `testHasExplicitActiveConfigIsTrueForConfigDirEnvVar` below), so sandboxing this case
        // still requires an environment with no override at all -- relying on this machine having no
        // real `~/.config/anthropic/active_config` pointer file (verified absent).
        XCTAssertFalse(ProfilePaths.hasExplicitActiveConfig(environment: [:]))
    }

    func testHasExplicitActiveConfigIsTrueForProfileEnvVar() {
        XCTAssertTrue(ProfilePaths.hasExplicitActiveConfig(environment: ["ANTHROPIC_PROFILE": "work"]))
    }

    func testHasExplicitActiveConfigIsTrueForConfigDirEnvVar() {
        XCTAssertTrue(ProfilePaths.hasExplicitActiveConfig(environment: ["ANTHROPIC_CONFIG_DIR": "/tmp/anthropic"]))
    }

    func testHasExplicitActiveConfigIsTrueForPointerFile() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("work".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        XCTAssertTrue(ProfilePaths.hasExplicitActiveConfig(environment: environment))
    }

    // MARK: - requireHTTPS

    func testRequireHTTPSAcceptsHTTPS() throws {
        try ProfilePaths.requireHTTPS("https://api.anthropic.com")
    }

    func testRequireHTTPSAcceptsLoopbackVariants() throws {
        try ProfilePaths.requireHTTPS("http://localhost:8080")
        try ProfilePaths.requireHTTPS("http://127.0.0.1:8080")
        try ProfilePaths.requireHTTPS("http://[::1]:8080")
    }

    func testRequireHTTPSRejectsPlainHTTP() {
        XCTAssertThrowsError(try ProfilePaths.requireHTTPS("http://api.anthropic.com"))
    }

    // MARK: - file path construction

    func testConfigFilePathIsUnderConfigsSubdirectory() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        let path = try ProfilePaths.configFilePath(profile: "work", environment: environment)
        XCTAssertEqual(path.path, tempDir.appendingPathComponent("configs/work.json").path)
    }

    func testCredentialsFilePathIsUnderCredentialsSubdirectory() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        let path = try ProfilePaths.credentialsFilePath(profile: "work", environment: environment)
        XCTAssertEqual(path.path, tempDir.appendingPathComponent("credentials/work.json").path)
    }

    // MARK: - helpers

    private static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anthropic-swift-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
