import Anthropic

/// The `user_location` hint for the built-in web-search tool, on the params side. Ported from
/// `beta_managed_agents_user_location_param.py`. Unlike the response's `BetaManagedAgentsUserLocation`,
/// `type` is `Required` here, so it's sent as a fixed constant on every request rather than
/// merely a redundant echo.
public struct BetaManagedAgentsUserLocationParams: Encodable, Sendable, Equatable {
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

/// Ported from `beta_managed_agents_bash_tool_config_params.py`. `enabled`/`permissionPolicy` are
/// optional overrides -- omit to fall back to the toolset's `defaultConfig`.
public struct BetaManagedAgentsBashToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "bash"
    public let type = "bash"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_edit_tool_config_params.py`.
public struct BetaManagedAgentsEditToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "edit"
    public let type = "edit"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_glob_tool_config_params.py`.
public struct BetaManagedAgentsGlobToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "glob"
    public let type = "glob"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_grep_tool_config_params.py`.
public struct BetaManagedAgentsGrepToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "grep"
    public let type = "grep"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_read_tool_config_params.py`.
public struct BetaManagedAgentsReadToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "read"
    public let type = "read"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_write_tool_config_params.py`.
public struct BetaManagedAgentsWriteToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "write"
    public let type = "write"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?

    public init(enabled: Bool? = nil, permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
    }
}

/// Ported from `beta_managed_agents_web_fetch_tool_config_params.py`.
public struct BetaManagedAgentsWebFetchToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "web_fetch"
    public let type = "web_fetch"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let maxContentTokens: Int?

    public init(
        enabled: Bool? = nil,
        permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        maxContentTokens: Int? = nil
    ) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.maxContentTokens = maxContentTokens
    }
}

/// Ported from `beta_managed_agents_web_search_tool_config_params.py`.
public struct BetaManagedAgentsWebSearchToolConfigParams: Encodable, Sendable, Equatable {
    public let name = "web_search"
    public let type = "web_search"
    public let enabled: Bool?
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy?
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let userLocation: BetaManagedAgentsUserLocationParams?

    public init(
        enabled: Bool? = nil,
        permissionPolicy: BetaManagedAgentsPermissionPolicy? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        userLocation: BetaManagedAgentsUserLocationParams? = nil
    ) {
        self.enabled = enabled
        self.permissionPolicy = permissionPolicy
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.userLocation = userLocation
    }
}

/// Ported from `beta_managed_agents_agent_tool_config_params.py`'s `AgentToolConfig` union -- the
/// params-side counterpart to `BetaManagedAgentsAgentToolConfig`.
///
/// **Discriminator deviation, confirmed by reading the Python source directly (not assumed):**
/// the response-side union is discriminated by `type` (`PropertyInfo(discriminator="type")`), but
/// each *params* leaf type (e.g. `beta_managed_agents_bash_tool_config_params.py`) instead marks
/// `name: Required[Literal["bash"]]` as its real discriminator, with `type` present but merely
/// `NotRequired` (redundant). Since every leaf struct here already encodes its own fixed `name`
/// constant, this union needs no discriminator logic of its own -- `encode(to:)` is a plain
/// switch, matching this codebase's convention for request-only unions whose leaves are
/// self-describing.
public enum BetaManagedAgentsAgentToolConfigParams: Sendable, Equatable {
    case bash(BetaManagedAgentsBashToolConfigParams)
    case edit(BetaManagedAgentsEditToolConfigParams)
    case glob(BetaManagedAgentsGlobToolConfigParams)
    case grep(BetaManagedAgentsGrepToolConfigParams)
    case read(BetaManagedAgentsReadToolConfigParams)
    case write(BetaManagedAgentsWriteToolConfigParams)
    case webFetch(BetaManagedAgentsWebFetchToolConfigParams)
    case webSearch(BetaManagedAgentsWebSearchToolConfigParams)
}

extension BetaManagedAgentsAgentToolConfigParams: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .bash(let value): try value.encode(to: encoder)
        case .edit(let value): try value.encode(to: encoder)
        case .glob(let value): try value.encode(to: encoder)
        case .grep(let value): try value.encode(to: encoder)
        case .read(let value): try value.encode(to: encoder)
        case .write(let value): try value.encode(to: encoder)
        case .webFetch(let value): try value.encode(to: encoder)
        case .webSearch(let value): try value.encode(to: encoder)
        }
    }
}
