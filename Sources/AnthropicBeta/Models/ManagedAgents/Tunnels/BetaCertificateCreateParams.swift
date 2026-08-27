/// Mirrors `types/beta/tunnels/certificate_create_params.py`.
public struct BetaCertificateCreateParams: Encodable, Sendable, Equatable {
    public var caCertificatePem: String

    public init(caCertificatePem: String) {
        self.caCertificatePem = caCertificatePem
    }
}
