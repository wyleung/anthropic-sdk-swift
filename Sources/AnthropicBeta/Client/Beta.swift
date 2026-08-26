import Anthropic

/// Entry point for the Beta surface, mirroring the reference SDKs' `client.beta`. Every Beta
/// endpoint sends `beta=true` and, where applicable, an `anthropic-beta` header -- see
/// `betaRequestOptions` below for how those are threaded through `RequestOptions` without
/// requiring callers to build headers by hand.
public struct Beta: Sendable {
    unowned let client: AnthropicClient

    public var messages: BetaMessages { BetaMessages(client: client) }
    public var models: BetaModels { BetaModels(client: client) }
    public var files: BetaFiles { BetaFiles(client: client) }
    public var skills: BetaSkills { BetaSkills(client: client) }
}

extension AnthropicClient {
    public var beta: Beta { Beta(client: self) }
}

/// Every Beta transport call needs `beta=true` as a query parameter -- unlike the reference SDKs,
/// which bake a literal `?beta=true` suffix onto the path string, this port passes it through
/// `HTTPTransport`'s existing `query` parameter: `URL.appendingPathComponent` percent-encodes a
/// literal `?` in a path string (turning it into `%3F`), so a hardcoded path suffix would silently
/// send a broken URL. Threading it as a real query item avoids that entirely while producing the
/// same `?beta=true` on the wire.
let betaQuery: [String: String?] = ["beta": "true"]

/// Merges the `betas` list (and, for endpoints like Files/Skills that require one, a mandatory
/// beta flag) into `anthropic-beta`, without clobbering a header the caller already set explicitly
/// via `options.headers` -- matching the reference SDKs' `extra_headers` always taking precedence.
func betaRequestOptions(
    betas: [String], requiredBeta: String? = nil, userProfileId: String? = nil, base options: RequestOptions
) -> RequestOptions {
    var merged = options
    if merged.headers["anthropic-beta"] == nil {
        var flags = betas
        if let requiredBeta, !flags.contains(requiredBeta) {
            flags.append(requiredBeta)
        }
        if !flags.isEmpty {
            merged.headers["anthropic-beta"] = flags.joined(separator: ",")
        }
    }
    if let userProfileId, merged.headers["anthropic-user-profile-id"] == nil {
        merged.headers["anthropic-user-profile-id"] = userProfileId
    }
    return merged
}
