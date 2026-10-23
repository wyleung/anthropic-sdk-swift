import Foundation

/// The headers of one request, layered from lowest to highest priority and compared
/// case-insensitively, the way HTTP defines header names.
///
/// A plain `[String: String]` treats `Authorization` and `authorization` as two entries, so a header a
/// caller supplied in a different casing than the one a credential provider used would sit beside it
/// and `URLRequest` would apply whichever the dictionary happened to iterate last. Here the later layer
/// wins, deterministically, and keeps its own casing on the wire (a few headers, such as
/// `Anthropic-Worker-ID`, are mixed-case on purpose to match the reference SDKs).
struct RequestHeaders {
    private var entries: [String: (name: String, value: String)] = [:]

    var all: [(name: String, value: String)] {
        entries.values.map { (name: $0.name, value: $0.value) }
    }

    func value(for name: String) -> String? {
        entries[name.lowercased()]?.value
    }

    mutating func set(_ name: String, _ value: String) {
        entries[name.lowercased()] = (name: name, value: value)
    }

    mutating func remove(_ name: String) {
        entries.removeValue(forKey: name.lowercased())
    }

    /// Applies per-call overrides: a value replaces the header, `nil` removes it.
    mutating func apply(_ overrides: [String: String?]) {
        for (name, value) in overrides {
            if let value {
                set(name, value)
            } else {
                remove(name)
            }
        }
    }

    /// Adds the flags in `added` to the `anthropic-beta` header already present, keeping each flag once.
    ///
    /// `anthropic-beta` is a comma-separated set, not a scalar, so a credential provider's flag (the
    /// `oauth-2025-04-20` marker an OAuth bearer token needs) has to join the call's own flags rather
    /// than replace them. Matches Python's `AccessTokenAuth._apply`: whole flags are compared after
    /// trimming, existing flags keep their order, and new ones follow.
    mutating func mergeBetaFlags(_ added: String) {
        var flags = Self.betaFlags(in: value(for: "anthropic-beta") ?? "")
        for flag in Self.betaFlags(in: added) where !flags.contains(flag) {
            flags.append(flag)
        }
        guard !flags.isEmpty else { return }
        // Keep whichever casing the request already used for the header name.
        let existingName = entries["anthropic-beta"]?.name ?? "anthropic-beta"
        set(existingName, flags.joined(separator: ","))
    }

    private static func betaFlags(in header: String) -> [String] {
        header.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
