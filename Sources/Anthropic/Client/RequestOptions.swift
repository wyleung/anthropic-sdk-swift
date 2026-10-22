import Foundation

/// Per-call overrides layered on top of `AnthropicClient`'s defaults.
///
/// A header set to `nil` explicitly unsets a default header rather than being ignored.
public struct RequestOptions: Sendable {
    public var headers: [String: String?]
    public var maxRetries: Int?
    public var timeout: TimeInterval?

    /// - Parameter workspaceId: Selects the Workspace for this request (a `wrkspc_...` ID) by setting
    ///   the `anthropic-workspace-id` header -- the reference SDKs' per-method `workspace_id`
    ///   parameter, here usable on every GA and Beta method at once. It wins over a header of the same
    ///   name in `headers`. Deliberately not a stored property: it is folded into `headers` so that
    ///   code that rebuilds a `RequestOptions` from `headers` can't silently lose it.
    public init(
        headers: [String: String?] = [:],
        maxRetries: Int? = nil,
        timeout: TimeInterval? = nil,
        workspaceId: String? = nil
    ) {
        var headers = headers
        if let workspaceId {
            headers = headers.filter { $0.key.caseInsensitiveCompare(Self.workspaceHeader) != .orderedSame }
            headers[Self.workspaceHeader] = workspaceId
        }
        self.headers = headers
        self.maxRetries = maxRetries
        self.timeout = timeout
    }

    private static let workspaceHeader = "anthropic-workspace-id"
}
