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
            throw AnthropicError.credentials(message: "Profile name must not be empty.")
        }
        guard name == name.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw AnthropicError.credentials(
                message: "Profile name \"\(name)\" must not have leading or trailing whitespace."
            )
        }
        guard !name.hasPrefix(".") else {
            throw AnthropicError.credentials(
                message: "Profile name \"\(name)\" must not start with \".\"."
            )
        }
        guard !name.contains("/"), !name.contains("\\") else {
            throw AnthropicError.credentials(
                message: "Profile name \"\(name)\" must not contain a path separator."
            )
        }
        guard !name.contains("\0") else {
            throw AnthropicError.credentials(
                message: "Profile name \"\(name)\" must not contain a NUL byte."
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

    /// Whether the user said where profiles live (`ANTHROPIC_CONFIG_DIR`) or which one is active (a
    /// non-empty `active_config` pointer file), as opposed to a `default` profile found only by
    /// passive discovery. Neither *selects* a profile ahead of other credentials -- `ANTHROPIC_PROFILE`
    /// does that -- but when resolution reaches the active profile, a broken one must then raise
    /// instead of being skipped.
    static func isActiveProfileUserConfigured(environment: [String: String]) -> Bool {
        if let configDir = environment["ANTHROPIC_CONFIG_DIR"], !configDir.isEmpty { return true }
        return readActiveConfigPointer(environment: environment) != nil
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
            throw AnthropicError.credentials(
                message: "Resolved path escapes the Anthropic config directory."
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
        throw AnthropicError.credentials(
            message: "base_url \"\(urlString)\" must use https:// -- it may carry secret material."
        )
    }
}
