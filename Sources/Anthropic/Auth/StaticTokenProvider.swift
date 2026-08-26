/// Bearer-token auth for a statically supplied token (`ANTHROPIC_AUTH_TOKEN`), as opposed to an
/// `x-api-key`. Never refreshes or expires -- `invalidate()` is a no-op, matching the reference
/// SDKs.
public struct StaticTokenProvider: CredentialProvider {
    public let token: String

    public init(token: String) {
        self.token = token
    }

    public func authHeader() async throws -> (name: String, value: String) {
        ("authorization", "Bearer \(token)")
    }

    public func invalidate() async {}
}
