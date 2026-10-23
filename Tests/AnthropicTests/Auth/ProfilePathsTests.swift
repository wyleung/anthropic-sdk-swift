import XCTest
@testable import Anthropic

final class ProfilePathsTests: XCTestCase {
    // MARK: - validateProfileName

    func testValidateProfileNameAcceptsAnOrdinaryName() throws {
        XCTAssertEqual(try ProfilePaths.validateProfileName("work"), "work")
    }

    func testValidateProfileNameRejectsEmpty() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName(""))
    }

    func testValidateProfileNameRejectsLeadingWhitespace() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName(" work"))
    }

    func testValidateProfileNameRejectsTrailingWhitespace() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName("work "))
    }

    func testValidateProfileNameRejectsLeadingDot() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName(".work"))
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName(".."))
    }

    func testValidateProfileNameRejectsForwardSlash() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName("a/b"))
    }

    func testValidateProfileNameRejectsBackslash() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName("a\\b"))
    }

    func testValidateProfileNameRejectsNUL() {
        XCTAssertThrowsCredentialsError(try ProfilePaths.validateProfileName("a\0b"))
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

    // MARK: - isActiveProfileUserConfigured

    func testActiveProfileIsNotUserConfiguredWithNothingSet() {
        // Relies on this machine having no real `~/.config/anthropic/active_config` pointer file
        // (verified absent): with no `ANTHROPIC_CONFIG_DIR` there is no way to sandbox that lookup.
        XCTAssertFalse(ProfilePaths.isActiveProfileUserConfigured(environment: [:]))
    }

    func testProfileEnvVarAloneDoesNotMakeTheActiveProfileUserConfigured() {
        // `ANTHROPIC_PROFILE` is explicit *selection*, handled by the chain ahead of workload identity;
        // this predicate is only about whether a broken active profile should raise.
        XCTAssertFalse(ProfilePaths.isActiveProfileUserConfigured(environment: ["ANTHROPIC_PROFILE": "work"]))
    }

    func testConfigDirEnvVarMakesTheActiveProfileUserConfigured() {
        XCTAssertTrue(ProfilePaths.isActiveProfileUserConfigured(environment: ["ANTHROPIC_CONFIG_DIR": "/tmp/anthropic"]))
    }

    func testEmptyConfigDirEnvVarDoesNotCount() {
        XCTAssertFalse(ProfilePaths.isActiveProfileUserConfigured(environment: ["ANTHROPIC_CONFIG_DIR": ""]))
    }

    func testPointerFileMakesTheActiveProfileUserConfigured() throws {
        let tempDir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("work".utf8).write(to: tempDir.appendingPathComponent("active_config"))
        let environment = ["ANTHROPIC_CONFIG_DIR": tempDir.path]
        XCTAssertTrue(ProfilePaths.isActiveProfileUserConfigured(environment: environment))
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
        XCTAssertThrowsCredentialsError(try ProfilePaths.requireHTTPS("http://api.anthropic.com"))
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
