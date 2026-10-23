import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Reads and writes `credentials/<profile>.json` -- the secret, flat token file (as opposed to the
/// non-secret `configs/<profile>.json`). Ported from the reference SDKs' `_credentials_store.py` /
/// `credentials-store.ts`, keeping "Python parity" for the file-safety checks (a deliberate choice
/// confirmed with the maintainer rather than inventing a hybrid):
///
/// - A symlink is refused outright, never followed -- checked via `lstat`, never `FileManager`
///   (which follows symlinks and can't express "reject if symlink").
/// - Any group or other bit (`mode & 0o077`) is a hard failure -- read, write or execute. Python
///   tightened to this in 1.5.0/1.10.0; this port originally mirrored the earlier, weaker check
///   (refuse world-readable, only warn on group bits, never look at write bits).
/// - No uid-ownership check.
enum CredentialsStore {
    struct Credentials: Sendable {
        var type: String?
        var version: Int?
        var accessToken: String
        var expiresAt: Date?
        var refreshToken: String?
    }

    private static let oauthTokenType = "oauth_token"

    /// Full re-read on every call -- no caching -- since an external process (e.g. `claude setup-token`
    /// running concurrently) may rewrite the file between calls.
    static func read(profile: String, environment: [String: String]) throws -> Credentials? {
        let path = try ProfilePaths.credentialsFilePath(profile: profile, environment: environment)
        guard let statInfo = try lstatIfExists(path) else { return nil }
        try enforceSafety(statInfo, path: path)
        guard let data = try? Data(contentsOf: path) else { return nil }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AnthropicError.credentials(
                message: "Credentials file at \(path.path) is not a valid JSON object."
            )
        }
        return try parse(object, path: path)
    }

    /// Merges `accessToken`/`expiresAt`/`refreshToken` into whatever raw JSON object already exists
    /// on disk (preserving any other keys already there), then writes it back atomically.
    static func store(
        profile: String, environment: [String: String], accessToken: String, expiresAt: Date?, refreshToken: String?
    ) throws {
        var fields: [String: Any] = [
            "type": oauthTokenType,
            "access_token": accessToken,
        ]
        if let expiresAt { fields["expires_at"] = Int(expiresAt.timeIntervalSince1970) }
        if let refreshToken { fields["refresh_token"] = refreshToken }

        let path = try ProfilePaths.credentialsFilePath(profile: profile, environment: environment)
        var existing: [String: Any] = [:]
        if let statInfo = try lstatIfExists(path) {
            try enforceSafety(statInfo, path: path)
            if let data = try? Data(contentsOf: path),
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                existing = object
            }
        }
        for (key, value) in fields { existing[key] = value }
        try atomicWrite(existing, to: path)
    }

    private static func parse(_ object: [String: Any], path: URL) throws -> Credentials {
        if let typeValue = object["type"] as? String, typeValue != oauthTokenType {
            throw AnthropicError.credentials(
                message: "Credentials file at \(path.path) has unrecognized type \"\(typeValue)\"."
            )
        }
        guard let accessToken = object["access_token"] as? String, !accessToken.isEmpty else {
            throw AnthropicError.credentials(
                message: "Credentials file at \(path.path) is missing access_token."
            )
        }
        let expiresAt = (object["expires_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return Credentials(
            type: object["type"] as? String,
            version: (object["version"] as? NSNumber)?.intValue,
            accessToken: accessToken,
            expiresAt: expiresAt,
            refreshToken: object["refresh_token"] as? String
        )
    }

    // MARK: - POSIX safety checks

    private static func lstatIfExists(_ url: URL) throws -> stat? {
        var info = stat()
        let result = url.path.withCString { lstat($0, &info) }
        if result == 0 { return info }
        if errno == ENOENT { return nil }
        throw AnthropicError.credentials(
            message: "Could not stat \(url.path): \(String(cString: strerror(errno)))"
        )
    }

    private static func enforceSafety(_ info: stat, path: URL) throws {
        let fileType = info.st_mode & mode_t(S_IFMT)
        guard fileType != mode_t(S_IFLNK) else {
            throw AnthropicError.credentials(
                message: "Credentials file at \(path.path) is a symlink; refusing to read it."
            )
        }
        let permissionBits = info.st_mode & 0o7777
        guard permissionBits & 0o077 == 0 else {
            throw AnthropicError.credentials(
                message: "Credentials file at \(path.path) is accessible by group or others (mode " +
                    "0o\(String(permissionBits, radix: 8))); run `chmod 600 \(path.path)` before retrying."
            )
        }
    }

    // MARK: - Atomic write

    private static func ensureDirectoryExists(_ directory: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return
        }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
    }

    /// Temp-file-then-`rename` for atomicity, `fsync`ing the temp file before the rename and the
    /// containing directory after -- so a crash never leaves a half-written credentials file, and
    /// the rename itself is durable.
    private static func atomicWrite(_ object: [String: Any], to path: URL) throws {
        let directory = path.deletingLastPathComponent()
        try ensureDirectoryExists(directory)
        let data = try JSONSerialization.data(withJSONObject: object)
        let tempPath = directory.appendingPathComponent(".\(path.lastPathComponent).\(UUID().uuidString).tmp")

        let fd = tempPath.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }
        guard fd >= 0 else {
            throw AnthropicError.credentials(
                message: "Could not create temporary credentials file at \(tempPath.path): " +
                    "\(String(cString: strerror(errno)))"
            )
        }
        defer { close(fd) }

        guard fchmod(fd, 0o600) == 0 else {
            throw storeCleanupError(
                "Could not set permissions on temporary credentials file", tempPath: tempPath
            )
        }
        guard writeAll(data, to: fd) else {
            throw storeCleanupError("Could not write temporary credentials file", tempPath: tempPath)
        }
        guard fsync(fd) == 0 else {
            throw storeCleanupError("Could not fsync temporary credentials file", tempPath: tempPath)
        }

        let renamed = tempPath.path.withCString { tmpCPath in
            path.path.withCString { finalCPath in rename(tmpCPath, finalCPath) }
        }
        guard renamed == 0 else {
            throw storeCleanupError("Could not move temporary credentials file into place", tempPath: tempPath)
        }

        let dirFd = directory.path.withCString { open($0, O_RDONLY) }
        if dirFd >= 0 {
            fsync(dirFd)
            close(dirFd)
        }
    }

    private static func writeAll(_ data: Data, to fd: Int32) -> Bool {
        data.withUnsafeBytes { rawBuffer -> Bool in
            guard let base = rawBuffer.baseAddress else { return true }
            var written = 0
            while written < rawBuffer.count {
                let n = Darwin.write(fd, base.advanced(by: written), rawBuffer.count - written)
                if n < 0 {
                    if errno == EINTR { continue }
                    return false
                }
                written += n
            }
            return true
        }
    }

    private static func storeCleanupError(_ prefix: String, tempPath: URL) -> AnthropicError {
        let message = "\(prefix): \(String(cString: strerror(errno)))"
        try? FileManager.default.removeItem(at: tempPath)
        return .credentials(message: message)
    }
}
