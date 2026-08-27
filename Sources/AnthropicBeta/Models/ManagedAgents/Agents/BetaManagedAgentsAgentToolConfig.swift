import Anthropic

/// The `user_location` hint for the built-in web-search tool, as returned in a response. Ported
/// from `beta_managed_agents_user_location.py`. Not a union -- Python only defines the
/// `"approximate"` kind today.
public struct BetaManagedAgentsUserLocation: Codable, Sendable, Equatable {
    public let type: String
    public let city: String?
    public let country: String?
    public let region: String?
    public let timezone: String?

    public init(
        type: String = "approximate",
        city: String? = nil,
        country: String? = nil,
        region: String? = nil,
        timezone: String? = nil
    ) {
        self.type = type
        self.city = city
        self.country = country
        self.region = region
        self.timezone = timezone
    }
}

/// Ported from `beta_managed_agents_bash_tool_config.py`.
public struct BetaManagedAgentsBashToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String

    public init(enabled: Bool, name: String = "bash", permissionPolicy: BetaManagedAgentsPermissionPolicy, type: String = "bash") {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
    }
}

/// Ported from `beta_managed_agents_edit_tool_config.py`.
public struct BetaManagedAgentsEditToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String

    public init(enabled: Bool, name: String = "edit", permissionPolicy: BetaManagedAgentsPermissionPolicy, type: String = "edit") {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
    }
}

/// Ported from `beta_managed_agents_glob_tool_config.py`.
public struct BetaManagedAgentsGlobToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String

    public init(enabled: Bool, name: String = "glob", permissionPolicy: BetaManagedAgentsPermissionPolicy, type: String = "glob") {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
    }
}

/// Ported from `beta_managed_agents_grep_tool_config.py`.
public struct BetaManagedAgentsGrepToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String

    public init(enabled: Bool, name: String = "grep", permissionPolicy: BetaManagedAgentsPermissionPolicy, type: String = "grep") {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
    }
}

/// Ported from `beta_managed_agents_read_tool_config.py`.
public struct BetaManagedAgentsReadToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String

    public init(enabled: Bool, name: String = "read", permissionPolicy: BetaManagedAgentsPermissionPolicy, type: String = "read") {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
    }
}

/// Ported from `beta_managed_agents_write_tool_config.py`.
public struct BetaManagedAgentsWriteToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String

    public init(enabled: Bool, name: String = "write", permissionPolicy: BetaManagedAgentsPermissionPolicy, type: String = "write") {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
    }
}

/// Ported from `beta_managed_agents_web_fetch_tool_config.py`. Adds `allowedDomains`/
/// `blockedDomains`/`maxContentTokens` on top of the common bash/edit/glob/grep/read/write shape.
public struct BetaManagedAgentsWebFetchToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let maxContentTokens: Int?

    public init(
        enabled: Bool,
        name: String = "web_fetch",
        permissionPolicy: BetaManagedAgentsPermissionPolicy,
        type: String = "web_fetch",
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        maxContentTokens: Int? = nil
    ) {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.maxContentTokens = maxContentTokens
    }
}

/// Ported from `beta_managed_agents_web_search_tool_config.py`. Adds `allowedDomains`/
/// `blockedDomains`/`userLocation` on top of the common shape.
public struct BetaManagedAgentsWebSearchToolConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let name: String
    public let permissionPolicy: BetaManagedAgentsPermissionPolicy
    public let type: String
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
    public let userLocation: BetaManagedAgentsUserLocation?

    public init(
        enabled: Bool,
        name: String = "web_search",
        permissionPolicy: BetaManagedAgentsPermissionPolicy,
        type: String = "web_search",
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        userLocation: BetaManagedAgentsUserLocation? = nil
    ) {
        self.enabled = enabled
        self.name = name
        self.permissionPolicy = permissionPolicy
        self.type = type
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.userLocation = userLocation
    }
}

/// Ported from `beta_managed_agents_agent_tool_config.py`'s `AgentToolConfig` union -- the 8
/// built-in tool configs, discriminated on `type` via `PropertyInfo(discriminator="type")`.
///
/// This is the RESPONSE side. The params-side equivalent
/// (`BetaManagedAgentsAgentToolConfigParams`) is discriminated by `name` instead, not `type` --
/// see the doc comment there for why the two sides genuinely differ.
public enum BetaManagedAgentsAgentToolConfig: Sendable, Equatable {
    case bash(BetaManagedAgentsBashToolConfig)
    case edit(BetaManagedAgentsEditToolConfig)
    case glob(BetaManagedAgentsGlobToolConfig)
    case grep(BetaManagedAgentsGrepToolConfig)
    case read(BetaManagedAgentsReadToolConfig)
    case write(BetaManagedAgentsWriteToolConfig)
    case webFetch(BetaManagedAgentsWebFetchToolConfig)
    case webSearch(BetaManagedAgentsWebSearchToolConfig)
    case unknown(type: String, raw: JSONValue)
}

extension BetaManagedAgentsAgentToolConfig: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "bash": self = .bash(try BetaManagedAgentsBashToolConfig(from: decoder))
        case "edit": self = .edit(try BetaManagedAgentsEditToolConfig(from: decoder))
        case "glob": self = .glob(try BetaManagedAgentsGlobToolConfig(from: decoder))
        case "grep": self = .grep(try BetaManagedAgentsGrepToolConfig(from: decoder))
        case "read": self = .read(try BetaManagedAgentsReadToolConfig(from: decoder))
        case "write": self = .write(try BetaManagedAgentsWriteToolConfig(from: decoder))
        case "web_fetch": self = .webFetch(try BetaManagedAgentsWebFetchToolConfig(from: decoder))
        case "web_search": self = .webSearch(try BetaManagedAgentsWebSearchToolConfig(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

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
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
