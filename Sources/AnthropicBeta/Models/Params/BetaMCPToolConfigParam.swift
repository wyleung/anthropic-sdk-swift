/// Ported from `types/beta/beta_mcp_tool_config_param.py`. Field-identical to
/// `BetaMCPToolDefaultConfigParam`, but kept as a distinct type since the Python source declares
/// them as two separate named types with different call sites (per-tool override vs. server-wide
/// default in `BetaMCPToolsetParam`).
public struct BetaMCPToolConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}
