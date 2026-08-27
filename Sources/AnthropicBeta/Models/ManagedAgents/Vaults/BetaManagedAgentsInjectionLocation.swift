/// Which parts of a proxied MCP request get the environment-variable secret injected. Not a
/// discriminated union -- Python's params/update/response variants all share the same plain
/// `{body, header}` shape (`beta_managed_agents_injection_location_{params,response,update_params}.py`),
/// differing only in field optionality.
public struct BetaManagedAgentsInjectionLocationParams: Encodable, Sendable, Equatable {
    public var body: Bool?
    public var header: Bool?

    public init(body: Bool? = nil, header: Bool? = nil) {
        self.body = body
        self.header = header
    }
}

public struct BetaManagedAgentsInjectionLocationResponse: Codable, Sendable, Equatable {
    public let body: Bool
    public let header: Bool

    public init(body: Bool, header: Bool) {
        self.body = body
        self.header = header
    }
}

public struct BetaManagedAgentsInjectionLocationUpdateParams: Encodable, Sendable, Equatable {
    public var body: Bool?
    public var header: Bool?

    public init(body: Bool? = nil, header: Bool? = nil) {
        self.body = body
        self.header = header
    }
}
