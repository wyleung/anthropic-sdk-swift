import Anthropic

/// An MCP server definition attached to an agent, as returned in a `BetaManagedAgentsAgent`
/// response. Ported from `beta_managed_agents_mcp_server_url_definition.py`. Modeled as a plain
/// struct rather than a union -- the Python source currently defines only one MCP server kind
/// (`url`), with no discriminated union type alias wrapping it.
public struct BetaManagedAgentsMCPServerURLDefinition: Codable, Sendable, Equatable {
    public let name: String
    public let type: String
    public let url: String

    public init(name: String, type: String = "url", url: String) {
        self.name = name
        self.type = type
        self.url = url
    }
}

/// Ported from `beta_managed_agents_url_mcp_server_params.py`.
public struct BetaManagedAgentsURLMCPServerParams: Encodable, Sendable, Equatable {
    public let name: String
    public let type = "url"
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}
