public enum ToolResponseInclusion: String, Encodable, Sendable, Equatable {
    case full
    case excluded
}

public struct UserLocationParam: Encodable, Sendable, Equatable {
    public let type = "approximate"
    public let city: String?
    public let country: String?
    public let region: String?
    public let timezone: String?

    public init(city: String? = nil, country: String? = nil, region: String? = nil, timezone: String? = nil) {
        self.city = city
        self.country = country
        self.region = region
        self.timezone = timezone
    }
}

public struct WebSearchTool20250305Param: Encodable, Sendable, Equatable {
    public let name = "web_search"
    public let type = "web_search_20250305"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let maxUses: Int?
    public let strict: Bool?
    public let userLocation: UserLocationParam?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        maxUses: Int? = nil,
        strict: Bool? = nil,
        userLocation: UserLocationParam? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.maxUses = maxUses
        self.strict = strict
        self.userLocation = userLocation
    }
}

public struct WebSearchTool20260209Param: Encodable, Sendable, Equatable {
    public let name = "web_search"
    public let type = "web_search_20260209"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let maxUses: Int?
    public let strict: Bool?
    public let userLocation: UserLocationParam?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        maxUses: Int? = nil,
        strict: Bool? = nil,
        userLocation: UserLocationParam? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.maxUses = maxUses
        self.strict = strict
        self.userLocation = userLocation
    }
}

public struct WebSearchTool20260318Param: Encodable, Sendable, Equatable {
    public let name = "web_search"
    public let type = "web_search_20260318"
    public let allowedCallers: [AllowedCaller]?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let maxUses: Int?
    public let responseInclusion: ToolResponseInclusion?
    public let strict: Bool?
    public let userLocation: UserLocationParam?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        maxUses: Int? = nil,
        responseInclusion: ToolResponseInclusion? = nil,
        strict: Bool? = nil,
        userLocation: UserLocationParam? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.maxUses = maxUses
        self.responseInclusion = responseInclusion
        self.strict = strict
        self.userLocation = userLocation
    }
}
