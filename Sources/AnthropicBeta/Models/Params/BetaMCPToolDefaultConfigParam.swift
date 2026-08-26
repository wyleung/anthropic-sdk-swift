/// Ported from `types/beta/beta_mcp_tool_default_config_param.py`. See `BetaMCPToolConfigParam` for
/// why this is a distinct type despite the identical field shape.
public struct BetaMCPToolDefaultConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}
