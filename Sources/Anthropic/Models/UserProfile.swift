/// Details about the entity a profile represents, as the platform states them. Ported from
/// `types/user_profile_external_user_details.py`; every field is optional.
public struct UserProfileExternalUserDetails: Codable, Sendable, Equatable {
    public let accountStatus: UserProfileExternalUserAccountStatus?
    public let country: String?
    /// A hash of the entity's email address, computed by the platform; opaque to Anthropic.
    public let emailHash: String?
    public let entityType: UserProfileExternalUserEntityType?
    public let nameHash: String?
    /// When the entity opened its account with the platform (RFC 3339).
    public let onboardedAt: String?
    /// The platform's own reference for the entity; not interpreted or enforced unique.
    public let referenceId: String?
}

/// An enforcement action Anthropic has opened on a profile. Both kinds share these fields; a ban has no
/// end date and cannot be cleared by the end user, so its `action` and `expiresAt` are always `nil`.
/// Ported from `types/user_profile_enforcement_action_{restriction,ban}.py`.
public struct UserProfileEnforcementActionRestriction: Codable, Sendable, Equatable {
    public let id: String
    /// What the end user can do to clear it.
    public let action: UserProfileEnforcementActionNextStep?
    public let expiresAt: String?
    public let openedAt: String
    public let reason: UserProfileEnforcementActionReason
    public let type: String
}

/// Anthropic has stopped serving the end user where the ban applies and does not plan to serve them there
/// again. Ported from `types/user_profile_enforcement_action_ban.py`.
public struct UserProfileEnforcementActionBan: Codable, Sendable, Equatable {
    public let id: String
    public let action: UserProfileEnforcementActionNextStep?
    public let expiresAt: String?
    public let openedAt: String
    public let reason: UserProfileEnforcementActionReason
    public let type: String
}

/// Ported from `types/user_profile_enforcement_action.py`.
public enum UserProfileEnforcementAction: Sendable, Equatable {
    case restriction(UserProfileEnforcementActionRestriction)
    case ban(UserProfileEnforcementActionBan)
    case unknown(type: String, raw: JSONValue)
}

extension UserProfileEnforcementAction: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: DiscriminatorKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "restriction": self = .restriction(try UserProfileEnforcementActionRestriction(from: decoder))
        case "ban": self = .ban(try UserProfileEnforcementActionBan(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .restriction(let value): try value.encode(to: encoder)
        case .ban(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Whether a Cyber Verification Program tier is switched on. Ported from `types/user_profile_cyber_tier.py`.
public struct UserProfileCyberTier: Codable, Sendable, Equatable {
    public let status: UserProfileProgramItemStatus
}

/// Ported from `types/user_profile_cyber_requirements.py`.
public struct UserProfileCyberRequirements: Codable, Sendable, Equatable {
    public let dataRetention: Bool
    public let humanReview: Bool
}

/// The profile's standing in the Cyber Verification Program. Ported from `types/user_profile_cyber_program.py`.
public struct UserProfileCyberProgram: Codable, Sendable, Equatable {
    public let requirements: UserProfileCyberRequirements?
    public let status: UserProfileProgramStatus
    /// Keyed by tier name.
    public let tiers: [String: UserProfileCyberTier]
}

/// Whether an EFS feature is switched on. Ported from `types/user_profile_efs_feature.py`.
public struct UserProfileEfsFeature: Codable, Sendable, Equatable {
    public let status: UserProfileProgramItemStatus
}

/// The profile's standing in the EFS program. Ported from `types/user_profile_efs_program.py`.
public struct UserProfileEfsProgram: Codable, Sendable, Equatable {
    /// Keyed by feature name.
    public let features: [String: UserProfileEfsFeature]
    public let status: UserProfileProgramStatus
}

/// The profile's standing in each Anthropic program. Ported from `types/user_profile_programs.py`.
public struct UserProfilePrograms: Codable, Sendable, Equatable {
    public let cyber: UserProfileCyberProgram?
    public let efs: UserProfileEfsProgram?
}

/// A record of an entity the platform serves through the API -- an end-user of its product, or a company it
/// resells Claude access to. Ported from `types/user_profile.py`. A Messages, Message Batches or token-counting
/// request can send a profile's `id` as `anthropic-user-profile-id` to attribute usage to it.
///
/// Only fields present in every response are non-optional; `accessType`, `enforcementActions`,
/// `enforcementStatus`, `externalUserDetails` and `programs` are optional because they postdate this port.
public struct UserProfile: Codable, Sendable, Equatable {
    public let id: String
    public let accessType: UserProfileAccessType?
    public let createdAt: String
    /// The enforcement actions open on this profile; empty when none is open.
    public let enforcementActions: [UserProfileEnforcementAction]?
    public let enforcementStatus: UserProfileEnforcementStatus?
    public let externalUserDetails: UserProfileExternalUserDetails?
    public let metadata: [String: String]
    public let name: String?
    public let programs: UserProfilePrograms?
    public let type: String
    public let updatedAt: String
}

/// Ported from `types/deleted_user_profile.py`.
public struct DeletedUserProfile: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
}

/// A one-time URL for an action the end user must take (such as enrolling). Ported from
/// `types/user_profiles/user_profile_action_url.py`.
public struct UserProfileActionURL: Codable, Sendable, Equatable {
    public let expiresAt: String
    public let type: String
    public let url: String
}
