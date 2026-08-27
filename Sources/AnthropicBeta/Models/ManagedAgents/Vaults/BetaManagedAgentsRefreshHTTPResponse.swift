/// The raw HTTP response captured while probing or refreshing an `mcp_oauth` credential. Ported
/// from `beta_managed_agents_refresh_http_response.py` -- a shared top-level type used by both
/// `BetaManagedAgentsMCPProbe.httpResponse` and `BetaManagedAgentsRefreshObject.httpResponse`, not a
/// type nested inside either.
public struct BetaManagedAgentsRefreshHTTPResponse: Codable, Sendable, Equatable {
    public let body: String
    public let bodyTruncated: Bool
    public let contentType: String
    public let statusCode: Int

    public init(body: String, bodyTruncated: Bool, contentType: String, statusCode: Int) {
        self.body = body
        self.bodyTruncated = bodyTruncated
        self.contentType = contentType
        self.statusCode = statusCode
    }
}
