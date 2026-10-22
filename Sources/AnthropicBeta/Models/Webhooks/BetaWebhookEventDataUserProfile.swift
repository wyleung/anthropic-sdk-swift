/// A user profile got an enforcement action. `id` is the profile's; `enforcementActionId` is the action's
/// (`enac_...`) -- fetch the profile (`client.userProfiles.retrieve`) to read the action itself. Ported from
/// `types/beta/beta_webhook_user_profile_enforcement_action_opened_event_data.py`. Unlike the other event
/// data, it carries no `workspaceId`.
public struct BetaWebhookUserProfileEnforcementActionOpenedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let enforcementActionId: String
    public let organizationId: String
    public let type: String

    public init(
        id: String, enforcementActionId: String, organizationId: String,
        type: String = "user_profile.enforcement_action_opened"
    ) {
        self.id = id
        self.enforcementActionId = enforcementActionId
        self.organizationId = organizationId
        self.type = type
    }
}

/// An enforcement action on a user profile was resolved. Ported from
/// `types/beta/beta_webhook_user_profile_enforcement_action_resolved_event_data.py`.
public struct BetaWebhookUserProfileEnforcementActionResolvedEventData: Codable, Sendable, Equatable {
    public let id: String
    public let enforcementActionId: String
    public let organizationId: String
    public let type: String

    public init(
        id: String, enforcementActionId: String, organizationId: String,
        type: String = "user_profile.enforcement_action_resolved"
    ) {
        self.id = id
        self.enforcementActionId = enforcementActionId
        self.organizationId = organizationId
        self.type = type
    }
}
