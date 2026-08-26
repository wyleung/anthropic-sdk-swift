public protocol CredentialProvider: Sendable {
    func authHeader() async throws -> (name: String, value: String)
    func invalidate() async
}

public struct APIKeyProvider: CredentialProvider {
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func authHeader() async throws -> (name: String, value: String) {
        ("x-api-key", apiKey)
    }

    public func invalidate() async {}
}
