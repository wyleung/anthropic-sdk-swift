/// Details about the entity a profile represents, as the platform states them. Ported from
/// `types/user_profile_external_user_details_params.py`; every field is optional.
///
/// On update, each field sent replaces the stored value and omitting one leaves it unchanged; once set, a
/// value cannot be cleared and `null` is rejected -- so plain optionals (omitted when `nil`) are exactly right.
public struct UserProfileExternalUserDetailsParams: Encodable, Sendable, Equatable {
    public let accountStatus: UserProfileExternalUserAccountStatus?
    public let country: String?
    /// A hash of the entity's email address, computed by the platform. Opaque to Anthropic, which doesn't
    /// prescribe the hash function. 1 to 255 characters.
    public let emailHash: String?
    public let entityType: UserProfileExternalUserEntityType?
    public let nameHash: String?
    /// When the entity opened its account with the platform, in RFC 3339 format: for an `application` profile,
    /// when the end-user signed up; for a `passthrough` profile, when the company became the platform's
    /// customer. Must be a complete timestamp no more than 1 minute in the future.
    public let onboardedAt: String?
    /// The platform's own reference for the entity, such as the key of the end-user's row in its database.
    /// Not interpreted by Anthropic and not enforced unique. 1 to 255 characters.
    public let referenceId: String?

    public init(
        accountStatus: UserProfileExternalUserAccountStatus? = nil,
        country: String? = nil,
        emailHash: String? = nil,
        entityType: UserProfileExternalUserEntityType? = nil,
        nameHash: String? = nil,
        onboardedAt: String? = nil,
        referenceId: String? = nil
    ) {
        self.accountStatus = accountStatus
        self.country = country
        self.emailHash = emailHash
        self.entityType = entityType
        self.nameHash = nameHash
        self.onboardedAt = onboardedAt
        self.referenceId = referenceId
    }
}

/// Ported from `types/user_profile_create_params.py`.
public struct UserProfileCreateParams: Encodable, Sendable, Equatable {
    /// How the platform uses the API for this entity; the server default is `application`.
    public let accessType: UserProfileAccessType?
    public let externalUserDetails: UserProfileExternalUserDetailsParams?
    public let metadata: [String: String]?
    /// The real-world name of the entity (a company or an individual). Maximum 255 characters.
    public let name: String?

    public init(
        accessType: UserProfileAccessType? = nil,
        externalUserDetails: UserProfileExternalUserDetailsParams? = nil,
        metadata: [String: String]? = nil,
        name: String? = nil
    ) {
        self.accessType = accessType
        self.externalUserDetails = externalUserDetails
        self.metadata = metadata
        self.name = name
    }
}

/// Ported from `types/user_profile_update_params.py`. Every field is "if present, replaces; omit to leave
/// unchanged", except `metadata`, which is *merged*: keys you send overwrite, and a key is removed by setting
/// its value to the empty string.
public struct UserProfileUpdateParams: Encodable, Sendable, Equatable {
    public let accessType: UserProfileAccessType?
    public let externalUserDetails: UserProfileExternalUserDetailsParams?
    /// Merged into the stored metadata: at most 16 keys, keys up to 64 characters, values up to 512.
    public let metadata: [String: String]?
    public let name: String?

    public init(
        accessType: UserProfileAccessType? = nil,
        externalUserDetails: UserProfileExternalUserDetailsParams? = nil,
        metadata: [String: String]? = nil,
        name: String? = nil
    ) {
        self.accessType = accessType
        self.externalUserDetails = externalUserDetails
        self.metadata = metadata
        self.name = name
    }
}

/// Asks for a URL the end user can use to enroll. Ported from
/// `types/user_profiles/user_profile_enroll_end_user_action_param.py`.
public struct UserProfileEnrollEndUserActionParam: Encodable, Sendable, Equatable {
    public let type = "enroll_end_user"

    public init() {}
}

/// Ported from `types/user_profiles/action_url_create_params.py`.
public struct UserProfileActionURLCreateParams: Encodable, Sendable, Equatable {
    public let action: UserProfileEnrollEndUserActionParam

    public init(action: UserProfileEnrollEndUserActionParam = UserProfileEnrollEndUserActionParam()) {
        self.action = action
    }
}
