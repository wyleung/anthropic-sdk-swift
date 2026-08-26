public struct WebFetchTool20250910Param: Encodable, Sendable, Equatable {
    public let name = "web_fetch"
    public let type = "web_fetch_20250910"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let citations: CitationsConfigParam?
    public let deferLoading: Bool?
    public let maxContentTokens: Int?
    public let maxUses: Int?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        citations: CitationsConfigParam? = nil,
        deferLoading: Bool? = nil,
        maxContentTokens: Int? = nil,
        maxUses: Int? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.citations = citations
        self.deferLoading = deferLoading
        self.maxContentTokens = maxContentTokens
        self.maxUses = maxUses
        self.strict = strict
    }
}

public struct WebFetchTool20260209Param: Encodable, Sendable, Equatable {
    public let name = "web_fetch"
    public let type = "web_fetch_20260209"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let citations: CitationsConfigParam?
    public let deferLoading: Bool?
    public let maxContentTokens: Int?
    public let maxUses: Int?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        citations: CitationsConfigParam? = nil,
        deferLoading: Bool? = nil,
        maxContentTokens: Int? = nil,
        maxUses: Int? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.citations = citations
        self.deferLoading = deferLoading
        self.maxContentTokens = maxContentTokens
        self.maxUses = maxUses
        self.strict = strict
    }
}

public struct WebFetchTool20260309Param: Encodable, Sendable, Equatable {
    public let name = "web_fetch"
    public let type = "web_fetch_20260309"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let citations: CitationsConfigParam?
    public let deferLoading: Bool?
    public let maxContentTokens: Int?
    public let maxUses: Int?
    public let strict: Bool?
    public let useCache: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        citations: CitationsConfigParam? = nil,
        deferLoading: Bool? = nil,
        maxContentTokens: Int? = nil,
        maxUses: Int? = nil,
        strict: Bool? = nil,
        useCache: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.citations = citations
        self.deferLoading = deferLoading
        self.maxContentTokens = maxContentTokens
        self.maxUses = maxUses
        self.strict = strict
        self.useCache = useCache
    }
}

public struct WebFetchTool20260318Param: Encodable, Sendable, Equatable {
    public let name = "web_fetch"
    public let type = "web_fetch_20260318"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let citations: CitationsConfigParam?
    public let deferLoading: Bool?
    public let maxContentTokens: Int?
    public let maxUses: Int?
    public let responseInclusion: ToolResponseInclusion?
    public let strict: Bool?
    public let useCache: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        citations: CitationsConfigParam? = nil,
        deferLoading: Bool? = nil,
        maxContentTokens: Int? = nil,
        maxUses: Int? = nil,
        responseInclusion: ToolResponseInclusion? = nil,
        strict: Bool? = nil,
        useCache: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.citations = citations
        self.deferLoading = deferLoading
        self.maxContentTokens = maxContentTokens
        self.maxUses = maxUses
        self.responseInclusion = responseInclusion
        self.strict = strict
        self.useCache = useCache
    }
}
