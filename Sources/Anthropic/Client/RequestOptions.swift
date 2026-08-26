import Foundation

/// Per-call overrides layered on top of `AnthropicClient`'s defaults.
///
/// A header set to `nil` explicitly unsets a default header rather than being ignored.
public struct RequestOptions: Sendable {
    public var headers: [String: String?]
    public var maxRetries: Int?
    public var timeout: TimeInterval?

    public init(
        headers: [String: String?] = [:],
        maxRetries: Int? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.headers = headers
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
}
