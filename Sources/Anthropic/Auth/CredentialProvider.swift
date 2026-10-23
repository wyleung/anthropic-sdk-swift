public protocol CredentialProvider: Sendable {
    func authHeader() async throws -> (name: String, value: String)

    /// Extra headers to send alongside `authHeader()` -- e.g. `anthropic-workspace-id` for
    /// `user_oauth` profiles, or the `anthropic-beta: oauth-2025-04-20` marker any Bearer-token
    /// provider needs. Defaults to none so existing conformers (like `APIKeyProvider`) are
    /// unaffected.
    func extraHeaders() async throws -> [String: String]

    func invalidate() async
}

extension CredentialProvider {
    public func extraHeaders() async throws -> [String: String] { [:] }
}

/// An API key, sent as `Authorization: Bearer <key>` (API version `2026-10-21` onward; earlier
/// versions used an `x-api-key` header). A key needs no token exchange, so unlike the OAuth-backed
/// providers it adds no `anthropic-beta` marker.
public struct APIKeyProvider: CredentialProvider {
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func authHeader() async throws -> (name: String, value: String) {
        ("authorization", "Bearer \(apiKey)")
    }

    public func invalidate() async {}
}
