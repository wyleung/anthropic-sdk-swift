/// Ported from `types/beta/beta_request_mcp_server_tool_configuration_param.py`.
public struct BetaRequestMCPServerToolConfigurationParam: Encodable, Sendable, Equatable {
    public let allowedTools: [String]?
    public let enabled: Bool?

    public init(allowedTools: [String]? = nil, enabled: Bool? = nil) {
        self.allowedTools = allowedTools
        self.enabled = enabled
    }
}
