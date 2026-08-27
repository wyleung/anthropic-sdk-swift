/// Mirrors `types/beta/beta_tunnel.py`.
public struct BetaTunnel: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let createdAt: String
    public let displayName: String?
    public let domain: String
    public let type: String

    public init(
        id: String,
        archivedAt: String? = nil,
        createdAt: String,
        displayName: String? = nil,
        domain: String,
        type: String = "tunnel"
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.displayName = displayName
        self.domain = domain
        self.type = type
    }
}
