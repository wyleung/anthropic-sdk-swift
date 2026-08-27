import Anthropic

/// Confirmation that a `session` has been permanently deleted. Ported from
/// `beta_managed_agents_deleted_session.py`. Distinct from `BetaManagedAgentsDeleteSessionResource`
/// (`type: "session_resource_deleted"`, past-tense-object naming) -- Python keeps session-level and
/// resource-level delete confirmations as two separate types, and this port mirrors that.
public struct BetaManagedAgentsDeletedSession: Codable, Sendable, Equatable {
    public let id: String
    public let type: String

    public init(id: String, type: String = "session_deleted") {
        self.id = id
        self.type = type
    }
}
