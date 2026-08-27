/// Mirrors `types/beta/beta_tunnel_token.py`. `tunnelToken` is a live connector credential --
/// treat it like any other secret (no default logging/interpolation convenience), the same
/// write-only-secret convention applied to vault credentials elsewhere in this cluster.
public struct BetaTunnelToken: Codable, Sendable, Equatable {
    public let id: String
    public let tunnelToken: String
    public let type: String

    public init(id: String, tunnelToken: String, type: String = "tunnel_token") {
        self.id = id
        self.tunnelToken = tunnelToken
        self.type = type
    }
}
