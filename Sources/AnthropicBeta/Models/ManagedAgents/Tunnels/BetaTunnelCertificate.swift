/// Mirrors `types/beta/tunnels/beta_tunnel_certificate.py`. The server never echoes the PEM
/// submitted at creation back in any response -- only `fingerprint` (a lowercase hex SHA-256 of
/// the certificate's DER encoding) is ever returned.
public struct BetaTunnelCertificate: Codable, Sendable, Equatable {
    public let id: String
    public let archivedAt: String?
    public let createdAt: String
    public let expiresAt: String?
    public let fingerprint: String
    public let tunnelId: String
    public let type: String

    public init(
        id: String,
        archivedAt: String? = nil,
        createdAt: String,
        expiresAt: String? = nil,
        fingerprint: String,
        tunnelId: String,
        type: String = "tunnel_certificate"
    ) {
        self.id = id
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.fingerprint = fingerprint
        self.tunnelId = tunnelId
        self.type = type
    }
}
