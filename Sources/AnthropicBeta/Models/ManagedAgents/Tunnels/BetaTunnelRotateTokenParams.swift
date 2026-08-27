/// Mirrors `types/beta/tunnel_rotate_token_params.py`.
public struct BetaTunnelRotateTokenParams: Encodable, Sendable, Equatable {
    public var reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}
