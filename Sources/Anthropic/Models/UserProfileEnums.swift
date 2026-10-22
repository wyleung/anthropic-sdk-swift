/// The open string enums of the user-profile model. Each decodes an unrecognized wire value to `.unknown`
/// rather than failing the whole profile: enforcement reasons, statuses and program states are
/// server-controlled sets that grow. Ported from `types/user_profile_*.py` literals.

/// How the platform uses the API for an entity. `application` (the default): the profile represents an
/// individual end-user of the platform's product. `passthrough`: it identifies a company the platform
/// resells Claude access to. Ported from `user_profile_access_type.py`.
public enum UserProfileAccessType: Sendable, Equatable {
    case application
    case passthrough
    case unknown(String)
}

extension UserProfileAccessType: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "application": self = .application
        case "passthrough": self = .passthrough
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .application: try container.encode("application")
        case .passthrough: try container.encode("passthrough")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// The end user's account standing with the platform, as the platform states it. Ported from
/// `user_profile_external_user_account_status.py`.
public enum UserProfileExternalUserAccountStatus: Sendable, Equatable {
    case active
    case suspended
    case blocked
    case unknown(String)
}

extension UserProfileExternalUserAccountStatus: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "active": self = .active
        case "suspended": self = .suspended
        case "blocked": self = .blocked
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active: try container.encode("active")
        case .suspended: try container.encode("suspended")
        case .blocked: try container.encode("blocked")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// What kind of entity a profile represents. Ported from `user_profile_external_user_entity_type.py`.
public enum UserProfileExternalUserEntityType: Sendable, Equatable {
    case individual
    case business
    case nonProfit
    case government
    case unknown(String)
}

extension UserProfileExternalUserEntityType: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "individual": self = .individual
        case "business": self = .business
        case "non_profit": self = .nonProfit
        case "government": self = .government
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .individual: try container.encode("individual")
        case .business: try container.encode("business")
        case .nonProfit: try container.encode("non_profit")
        case .government: try container.encode("government")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// Anthropic's enforcement status of a profile, from its open enforcement actions and any identity check
/// under review, by the first rule that applies:
///
/// - `banned` while any open action is a ban;
/// - `pending` while a restriction that an identity check can clear is open, the end user has submitted that
///   check, Anthropic's review of it has not ended, and no open action's reason is `account_compromise`;
/// - `restricted` while any action is open;
/// - `unrestricted` while none is.
///
/// Ported from `user_profile_enforcement_status.py`.
public enum UserProfileEnforcementStatus: Sendable, Equatable {
    case unrestricted
    case pending
    case restricted
    case banned
    case unknown(String)
}

extension UserProfileEnforcementStatus: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "unrestricted": self = .unrestricted
        case "pending": self = .pending
        case "restricted": self = .restricted
        case "banned": self = .banned
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unrestricted: try container.encode("unrestricted")
        case .pending: try container.encode("pending")
        case .restricted: try container.encode("restricted")
        case .banned: try container.encode("banned")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// Why Anthropic placed an enforcement limit. Ported from `user_profile_enforcement_action_reason.py`.
public enum UserProfileEnforcementActionReason: Sendable, Equatable {
    case unsupportedRegion
    case fraudOrAbuse
    case highHarm
    case usagePolicyViolation
    case accountCompromise
    case unspecified
    case unknown(String)
}

extension UserProfileEnforcementActionReason: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "unsupported_region": self = .unsupportedRegion
        case "fraud_or_abuse": self = .fraudOrAbuse
        case "high_harm": self = .highHarm
        case "usage_policy_violation": self = .usagePolicyViolation
        case "account_compromise": self = .accountCompromise
        case "unspecified": self = .unspecified
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unsupportedRegion: try container.encode("unsupported_region")
        case .fraudOrAbuse: try container.encode("fraud_or_abuse")
        case .highHarm: try container.encode("high_harm")
        case .usagePolicyViolation: try container.encode("usage_policy_violation")
        case .accountCompromise: try container.encode("account_compromise")
        case .unspecified: try container.encode("unspecified")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// What the end user can do to clear an enforcement action. Ported from
/// `user_profile_enforcement_action_next_step.py`.
public enum UserProfileEnforcementActionNextStep: Sendable, Equatable {
    case verify
    case unknown(String)
}

extension UserProfileEnforcementActionNextStep: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "verify" ? .verify : .unknown(raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .verify: try container.encode("verify")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// A profile's standing in an Anthropic program. Ported from `user_profile_program_status.py`.
public enum UserProfileProgramStatus: Sendable, Equatable {
    case active
    case pending
    case rejected
    case unknown(String)
}

extension UserProfileProgramStatus: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "active": self = .active
        case "pending": self = .pending
        case "rejected": self = .rejected
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active: try container.encode("active")
        case .pending: try container.encode("pending")
        case .rejected: try container.encode("rejected")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// Whether a program tier or feature is switched on. Ported from the `status` literal of
/// `user_profile_cyber_tier.py` and `user_profile_efs_feature.py`.
public enum UserProfileProgramItemStatus: Sendable, Equatable {
    case active
    case inactive
    case unknown(String)
}

extension UserProfileProgramItemStatus: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "active": self = .active
        case "inactive": self = .inactive
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active: try container.encode("active")
        case .inactive: try container.encode("inactive")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}
