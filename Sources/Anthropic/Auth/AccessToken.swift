import Foundation

/// A Bearer token obtained from the OAuth token endpoint (WIF exchange or `user_oauth` refresh),
/// plus the bookkeeping `TokenCache` needs to decide when it's stale.
struct AccessToken: Sendable, Equatable {
    var accessToken: String
    var expiresAt: Date?
    var refreshToken: String?
}
