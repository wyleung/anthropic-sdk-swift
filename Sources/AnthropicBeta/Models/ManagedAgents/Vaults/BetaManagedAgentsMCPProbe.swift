/// Ported from `beta_managed_agents_mcp_probe.py`. Describes the probe request `mcpOauthValidate`
/// made against the credential's MCP server.
public struct BetaManagedAgentsMCPProbe: Codable, Sendable, Equatable {
    public let httpResponse: BetaManagedAgentsRefreshHTTPResponse?
    public let method: String

    public init(httpResponse: BetaManagedAgentsRefreshHTTPResponse? = nil, method: String) {
        self.httpResponse = httpResponse
        self.method = method
    }
}
