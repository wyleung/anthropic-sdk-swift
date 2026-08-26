import Foundation

/// Directory/file layout and profile-name validation for on-disk credential profiles, ported from
/// the reference SDKs' `_constants.py` / `credential-chain.ts`. Apple platforms only, so this only
/// implements the Linux/macOS branch of the reference logic (`~/.config/anthropic/`), never the
/// Windows `%APPDATA%\Anthropic\` branch.
enum ProfilePaths {
    static let defaultProfile = "default"

    static func configDirectory(environment: [String: String]) -> URL {
        if let override = environment["ANTHROPIC_CONFIG_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("anthropic", isDirectory: true)
    }

    /// Mirrors `_validate_profile_name()`: rejects empty names, leading/trailing whitespace, a
    /// leading `.` (which also catches `..`), path separators, and NUL bytes.
    static func validateProfileName(_ name: String) throws -> String {
        guard !name.isEmpty else {
            throw AnthropicError.responseValidation(message: "Profile name must not be empty.", body: nil)
        }
        guard name == name.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw AnthropicError.responseValidation(
                message: "Profile name \"\(name)\" must not have leading or trailing whitespace.", body: nil
            )
        }
        guard !name.hasPrefix(".") else {
            throw AnthropicError.responseValidation(
                message: "Profile name \"\(name)\" must not start with \".\".", body: nil
            )
        }
        guard !name.contains("/"), !name.contains("\\") else {
            throw AnthropicError.responseValidation(
                message: "Profile name \"\(name)\" must not contain a path separator.", body: nil
            )
        }
        guard !name.contains("\0") else {
            throw AnthropicError.responseValidation(
                message: "Profile name \"\(name)\" must not contain a NUL byte.", body: nil
            )
        }
        return name
    }

    /// `ANTHROPIC_PROFILE` env var > the `active_config` pointer file > the literal `"default"`.
    static func activeProfile(environment: [String: String]) throws -> String {
        if let envProfile = environment["ANTHROPIC_PROFILE"], !envProfile.isEmpty {
            return try validateProfileName(envProfile)
        }
        if let pointer = readActiveConfigPointer(environment: environment) {
            return try validateProfileName(pointer)
        }
        return defaultProfile
    }

    static func readActiveConfigPointer(environment: [String: String]) -> String? {
        let path = configDirectory(environment: environment).appendingPathComponent("active_config")
        guard let data = try? Data(contentsOf: path), let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Whether *something* explicitly points at a profile (as opposed to a passively-discovered
    /// `default` profile) -- used to decide whether a broken config should raise (explicit
    /// selection) or be silently skipped (passive fallback).
    static func hasExplicitActiveConfig(environment: [String: String]) -> Bool {
        if let profile = environment["ANTHROPIC_PROFILE"], !profile.isEmpty { return true }
        if let configDir = environment["ANTHROPIC_CONFIG_DIR"], !configDir.isEmpty { return true }
        if readActiveConfigPointer(environment: environment) != nil { return true }
        return false
    }

    static func configFilePath(profile: String, environment: [String: String]) throws -> URL {
        let validated = try validateProfileName(profile)
        return try resolvedUnder(
            base: configDirectory(environment: environment), relative: "configs/\(validated).json"
        )
    }

    static func credentialsFilePath(profile: String, environment: [String: String]) throws -> URL {
        let validated = try validateProfileName(profile)
        return try resolvedUnder(
            base: configDirectory(environment: environment), relative: "credentials/\(validated).json"
        )
    }

    /// Defense-in-depth containment check mirroring `_resolve_under()`: the profile name is
    /// already validated above, so this should never actually trigger, but guards against future
    /// callers building a path some other way.
    private static func resolvedUnder(base: URL, relative: String) throws -> URL {
        let candidate = base.appendingPathComponent(relative)
        let standardizedBase = base.standardizedFileURL.path
        let standardizedCandidate = candidate.standardizedFileURL.path
        guard standardizedCandidate == standardizedBase
            || standardizedCandidate.hasPrefix(standardizedBase + "/")
        else {
            throw AnthropicError.responseValidation(
                message: "Resolved path escapes the Anthropic config directory.", body: nil
            )
        }
        return candidate
    }

    /// Mirrors `_require_https()`: a `base_url` read from a config file may carry secret material
    /// in query params/headers set elsewhere, so only `https://` (plus loopback for local dev) is
    /// accepted.
    static func requireHTTPS(_ urlString: String) throws {
        if urlString.hasPrefix("https://") { return }
        let allowedLoopbackPrefixes = ["http://localhost", "http://127.0.0.1", "http://[::1]"]
        if allowedLoopbackPrefixes.contains(where: { urlString.hasPrefix($0) }) { return }
        throw AnthropicError.responseValidation(
            message: "base_url \"\(urlString)\" must use https:// -- it may carry secret material.", body: nil
        )
    }
}
