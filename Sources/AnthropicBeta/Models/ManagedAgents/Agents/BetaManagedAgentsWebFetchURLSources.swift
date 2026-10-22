import Anthropic

/// Names a tool declared on the agent. Ported from `beta_managed_agents_web_fetch_url_source_tool_reference.py`.
public struct BetaManagedAgentsWebFetchURLSourceToolReference: Codable, Sendable, Equatable {
    public let name: String
    public let type: String

    public init(name: String, type: String = "tool_reference") {
        self.name = name
        self.type = type
    }
}

/// Which tools' results contribute fetchable URLs. Ported from
/// `beta_managed_agents_web_fetch_url_source_tool_filter.py` and its four variants. `.nothing` is the wire's
/// `"none"` -- renamed because a payload-free `.none` collides with `Optional.none`.
public enum BetaManagedAgentsWebFetchURLSourceToolFilter: Sendable, Equatable {
    case all
    case nothing
    case only([BetaManagedAgentsWebFetchURLSourceToolReference])
    case except([BetaManagedAgentsWebFetchURLSourceToolReference])
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsWebFetchURLSourceToolFilter: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, tools
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "all": self = .all
        case "none": self = .nothing
        case "only": self = .only(try container.decode([BetaManagedAgentsWebFetchURLSourceToolReference].self, forKey: .tools))
        case "except": self = .except(try container.decode([BetaManagedAgentsWebFetchURLSourceToolReference].self, forKey: .tools))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(_, let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all: try container.encode("all", forKey: .type)
        case .nothing: try container.encode("none", forKey: .type)
        case .only(let tools):
            try container.encode("only", forKey: .type)
            try container.encode(tools, forKey: .tools)
        case .except(let tools):
            try container.encode("except", forKey: .type)
            try container.encode(tools, forKey: .tools)
        case .unknown: break
        }
    }
}

/// Whether URLs in user messages are fetchable -- only `all` or `none`. Ported from
/// `beta_managed_agents_web_fetch_url_source_user_input.py`.
public enum BetaManagedAgentsWebFetchURLSourceUserInput: Sendable, Equatable {
    case all
    case nothing
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsWebFetchURLSourceUserInput: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "all": self = .all
        case "none": self = .nothing
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(_, let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self == .all ? "all" : "none", forKey: .type)
    }
}

/// Which sources contribute to the URLs web fetch may fetch; `nil` members mean every source. Ported from
/// `beta_managed_agents_web_fetch_url_sources.py`. The request side reuses `WebFetchURLSourcesParam`
/// (the field-identical object form -- the `"all"`/`"none"` string shorthand Python also accepts is just
/// a compact spelling of it).
public struct BetaManagedAgentsWebFetchURLSources: Codable, Sendable, Equatable {
    public let clientToolResults: BetaManagedAgentsWebFetchURLSourceToolFilter?
    public let serverToolResults: BetaManagedAgentsWebFetchURLSourceToolFilter?
    public let userInput: BetaManagedAgentsWebFetchURLSourceUserInput?

    public init(
        clientToolResults: BetaManagedAgentsWebFetchURLSourceToolFilter? = nil,
        serverToolResults: BetaManagedAgentsWebFetchURLSourceToolFilter? = nil,
        userInput: BetaManagedAgentsWebFetchURLSourceUserInput? = nil
    ) {
        self.clientToolResults = clientToolResults
        self.serverToolResults = serverToolResults
        self.userInput = userInput
    }
}
