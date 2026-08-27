/// Mirrors `types/beta/tunnel_create_params.py`.
public struct BetaTunnelCreateParams: Encodable, Sendable, Equatable {
    public var displayName: String?

    public init(displayName: String? = nil) {
        self.displayName = displayName
    }
}
