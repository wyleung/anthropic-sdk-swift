/// Ported from `types/beta/beta_request_mcp_server_url_definition_param.py`. Feeds
/// `BetaMessageCreateParams.mcpServers`.
public struct BetaRequestMCPServerURLDefinitionParam: Encodable, Sendable, Equatable {
    public let name: String
    public let type = "url"
    public let url: String
    public let authorizationToken: String?
    public let toolConfiguration: BetaRequestMCPServerToolConfigurationParam?

    public init(
        name: String, url: String, authorizationToken: String? = nil,
        toolConfiguration: BetaRequestMCPServerToolConfigurationParam? = nil
    ) {
        self.name = name
        self.url = url
        self.authorizationToken = authorizationToken
        self.toolConfiguration = toolConfiguration
    }
}
