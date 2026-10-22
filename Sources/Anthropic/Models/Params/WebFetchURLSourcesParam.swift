/// Names a tool declared in this request's `tools`. Ported from
/// `types/web_fetch_url_source_tool_reference_param.py`.
public struct WebFetchURLSourceToolReferenceParam: Encodable, Sendable, Equatable {
    public let type = "tool_reference"
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// A tool filter: which tools' results contribute fetchable URLs. Ported from the
/// `web_fetch_url_source_{all,none,only,except}_param.py` variants of `ClientToolResults` and
/// `ServerToolResults`.
///
/// `.nothing` is the wire's `"none"` -- renamed because a payload-free `.none` collides with
/// `Optional.none` wherever this appears as an optional parameter.
public enum WebFetchURLSourceParam: Sendable, Equatable {
    /// Every result of the filter's source contributes.
    case all
    /// No result of the filter's source contributes.
    case nothing
    /// Only the named tools' results contribute.
    case only([WebFetchURLSourceToolReferenceParam])
    /// Every result but the named tools' contributes.
    case except([WebFetchURLSourceToolReferenceParam])
}

extension WebFetchURLSourceParam: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, tools
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all:
            try container.encode("all", forKey: .type)
        case .nothing:
            try container.encode("none", forKey: .type)
        case .only(let tools):
            try container.encode("only", forKey: .type)
            try container.encode(tools, forKey: .tools)
        case .except(let tools):
            try container.encode("except", forKey: .type)
            try container.encode(tools, forKey: .tools)
        }
    }
}

/// Whether URLs in user messages are fetchable -- the narrower `UserInput` variant, which the wire
/// restricts to `all` or `none` (no `only`/`except`, since user input has no tools to name). A
/// separate type so the restriction is a compile-time fact rather than a runtime 400.
public enum WebFetchURLUserInputSourceParam: Sendable, Equatable {
    case all
    case nothing
}

extension WebFetchURLUserInputSourceParam: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all: try container.encode("all", forKey: .type)
        case .nothing: try container.encode("none", forKey: .type)
        }
    }
}

/// Which sources contribute to the set of URLs web fetch may fetch; omitted means every source.
/// Ported from `types/web_fetch_url_sources_param.py`. A tool named in `.only`/`.except` must be
/// declared in the same request's `tools`.
public struct WebFetchURLSourcesParam: Encodable, Sendable, Equatable {
    /// Which client tools' results contribute fetchable URLs.
    public let clientToolResults: WebFetchURLSourceParam?
    /// Which server tools' results contribute fetchable URLs; only `web_search` and `web_fetch`
    /// results ever do.
    public let serverToolResults: WebFetchURLSourceParam?
    public let userInput: WebFetchURLUserInputSourceParam?

    public init(
        clientToolResults: WebFetchURLSourceParam? = nil,
        serverToolResults: WebFetchURLSourceParam? = nil,
        userInput: WebFetchURLUserInputSourceParam? = nil
    ) {
        self.clientToolResults = clientToolResults
        self.serverToolResults = serverToolResults
        self.userInput = userInput
    }
}
