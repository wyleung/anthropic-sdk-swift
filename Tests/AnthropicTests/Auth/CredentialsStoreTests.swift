import XCTest
@testable import Anthropic

final class CredentialsStoreTests: XCTestCase {
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

    private var credentialsPath: URL { tempDir.appendingPathComponent("credentials/default.json") }

    func testReadReturnsNilWhenFileIsMissing() throws {
        XCTAssertNil(try CredentialsStore.read(profile: "default", environment: environment))
    }

    func testStoreThenReadRoundTripsAllFields() throws {
        let expiresAt = Date(timeIntervalSince1970: 1_800_000_000)
        try CredentialsStore.store(
            profile: "default", environment: environment,
            accessToken: "at-123", expiresAt: expiresAt, refreshToken: "rt-456"
        )
        let credentials = try XCTUnwrap(try CredentialsStore.read(profile: "default", environment: environment))
        XCTAssertEqual(credentials.accessToken, "at-123")
        XCTAssertEqual(credentials.refreshToken, "rt-456")
        XCTAssertEqual(credentials.expiresAt, expiresAt)
        XCTAssertEqual(credentials.type, "oauth_token")
    }

    func testStoreOmitsExpiresAtWhenNilRatherThanEncodingNull() throws {
        try CredentialsStore.store(
            profile: "default", environment: environment,
            accessToken: "at-123", expiresAt: nil, refreshToken: nil
        )
        let credentials = try XCTUnwrap(try CredentialsStore.read(profile: "default", environment: environment))
        XCTAssertNil(credentials.expiresAt)
        XCTAssertNil(credentials.refreshToken)
    }

    func testStorePreservesExistingKeysNotPassedOnASecondCall() throws {
        try CredentialsStore.store(
            profile: "default", environment: environment,
            accessToken: "at-1", expiresAt: nil, refreshToken: "rt-1"
        )
        // A second store call with no refreshToken should not erase the one already on disk --
        // `store` merges onto the existing JSON object rather than overwriting it wholesale.
        try CredentialsStore.store(
            profile: "default", environment: environment,
            accessToken: "at-2", expiresAt: nil, refreshToken: nil
        )
        let credentials = try XCTUnwrap(try CredentialsStore.read(profile: "default", environment: environment))
        XCTAssertEqual(credentials.accessToken, "at-2")
        XCTAssertEqual(credentials.refreshToken, "rt-1")
    }

    func testStoreWritesFileWithMode0600() throws {
        try CredentialsStore.store(
            profile: "default", environment: environment,
            accessToken: "at-123", expiresAt: nil, refreshToken: nil
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: credentialsPath.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions, 0o600)
    }

    func testReadThrowsOnWorldReadableFile() throws {
        try writeRawCredentialsFile(mode: 0o644)
        XCTAssertThrowsError(try CredentialsStore.read(profile: "default", environment: environment))
    }

    func testReadThrowsOnWorldReadableFileEvenWhenAlsoGroupReadable() throws {
        try writeRawCredentialsFile(mode: 0o664)
        XCTAssertThrowsError(try CredentialsStore.read(profile: "default", environment: environment))
    }

    func testReadWarnsButDoesNotThrowOnGroupReadableFile() throws {
        try writeRawCredentialsFile(mode: 0o640)
        let credentials = try XCTUnwrap(try CredentialsStore.read(profile: "default", environment: environment))
        XCTAssertEqual(credentials.accessToken, "at-raw")
    }

    func testReadSucceedsOnOwnerOnlyFile() throws {
        try writeRawCredentialsFile(mode: 0o600)
        let credentials = try XCTUnwrap(try CredentialsStore.read(profile: "default", environment: environment))
        XCTAssertEqual(credentials.accessToken, "at-raw")
    }

    func testReadThrowsOnSymlinkRegardlessOfItsOwnPermissions() throws {
        try FileManager.default.createDirectory(
            at: credentialsPath.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let realFile = tempDir.appendingPathComponent("real-credentials.json")
        try Data(#"{"access_token":"at-real"}"#.utf8).write(to: realFile)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: realFile.path)
        try FileManager.default.createSymbolicLink(at: credentialsPath, withDestinationURL: realFile)

        XCTAssertThrowsError(try CredentialsStore.read(profile: "default", environment: environment))
    }

    func testReadThrowsOnUnrecognizedType() throws {
        try FileManager.default.createDirectory(
            at: credentialsPath.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(#"{"type":"something_else","access_token":"at-raw"}"#.utf8).write(to: credentialsPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsPath.path)
        XCTAssertThrowsError(try CredentialsStore.read(profile: "default", environment: environment))
    }

    func testReadThrowsWhenAccessTokenIsMissing() throws {
        try FileManager.default.createDirectory(
            at: credentialsPath.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(#"{"type":"oauth_token"}"#.utf8).write(to: credentialsPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsPath.path)
        XCTAssertThrowsError(try CredentialsStore.read(profile: "default", environment: environment))
    }

    private func writeRawCredentialsFile(mode: Int) throws {
        try FileManager.default.createDirectory(
            at: credentialsPath.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(#"{"type":"oauth_token","access_token":"at-raw"}"#.utf8).write(to: credentialsPath)
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: credentialsPath.path)
    }
}
