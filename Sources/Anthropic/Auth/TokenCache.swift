import Foundation

/// Coalesces concurrent credential refreshes into a single in-flight `Task`, implementing the same
/// three-tier freshness policy as the reference SDKs' `_cache.py` / `token-cache.ts`:
///
/// - `remaining > 120s` (advisory threshold): serve the cached token, no network.
/// - `30s < remaining <= 120s`: serve the cached (stale) token immediately, but kick a background
///   refresh unless one is already in flight or a prior background refresh failed within the last
///   5s (`ADVISORY_REFRESH_BACKOFF_SECONDS`). A failed advisory refresh never raises.
/// - `remaining <= 30s` (or no cached token, or no expiry tracked but never populated): block until
///   a fresh token is obtained. If a refresh is already in flight, join it -- and if that join
///   fails, retry as the new leader rather than propagating the stale failure (matches Python's
///   `_cache.py` behavior: a mandatory-window waiter doesn't inherit someone else's transient
///   failure, it gets its own attempt).
///
/// Swift's actor isolation gives the same single-flight coalescing Python gets from a `Lock` +
/// `Event` pair, and TypeScript gets from a stored `Promise` -- no extra bookkeeping needed here.
actor TokenCache {
    private static let advisoryRefreshSeconds: TimeInterval = 120
    private static let mandatoryRefreshSeconds: TimeInterval = 30
    private static let advisoryRefreshBackoffSeconds: TimeInterval = 5

    private var cached: AccessToken?
    private var pendingRefresh: Task<AccessToken, Error>?
    private var lastAdvisoryFailureTime: Date?
    /// Set by `invalidate()`, cleared once a forced refresh succeeds (so a failed one still forces the
    /// next). While it is set, an *unforced* refresh that was already in flight when the token was
    /// invalidated must not be cached: it may have returned the very token that was rejected.
    private var forceNextRefresh = false

    /// Drops the cached token so the next call performs a fresh (mandatory-window) refresh, and marks
    /// that refresh as forced so an on-disk provider re-checks instead of re-serving the rejected token.
    func invalidate() {
        cached = nil
        forceNextRefresh = true
    }

    /// Returns a usable access token, per the freshness policy above. `provider` is called with
    /// `force: true` only when there is no cached token to fall back on (a "force" flag has no
    /// meaning against the reference implementations' provider signatures beyond that, since a
    /// jwt-bearer/refresh-token exchange always fetches a genuinely fresh token regardless).
    func token(provider: @escaping @Sendable (Bool) async throws -> AccessToken) async throws -> AccessToken {
        while true {
            if let cached {
                guard let expiresAt = cached.expiresAt else { return cached }
                let remaining = expiresAt.timeIntervalSinceNow
                if remaining > Self.advisoryRefreshSeconds {
                    return cached
                }
                if remaining > Self.mandatoryRefreshSeconds {
                    if pendingRefresh == nil, !isInAdvisoryBackoff {
                        beginRefresh(provider: provider, isAdvisory: true)
                    }
                    return cached
                }
            }

            if let pendingRefresh {
                do {
                    return try await pendingRefresh.value
                } catch {
                    continue
                }
            }
            return try await beginRefresh(provider: provider, isAdvisory: false).value
        }
    }

    private var isInAdvisoryBackoff: Bool {
        guard let lastAdvisoryFailureTime else { return false }
        return Date().timeIntervalSince(lastAdvisoryFailureTime) < Self.advisoryRefreshBackoffSeconds
    }

    @discardableResult
    private func beginRefresh(
        provider: @escaping @Sendable (Bool) async throws -> AccessToken, isAdvisory: Bool
    ) -> Task<AccessToken, Error> {
        let force = cached == nil || forceNextRefresh
        let task = Task {
            do {
                let token = try await provider(force)
                await self.completeRefresh(with: token, wasForced: force)
                return token
            } catch {
                await self.failRefresh(isAdvisory: isAdvisory)
                throw error
            }
        }
        pendingRefresh = task
        return task
    }

    private func completeRefresh(with token: AccessToken, wasForced: Bool) {
        // An unforced refresh that overlapped an `invalidate()` hands its token to the callers waiting on
        // it but is not cached: the next caller then makes the forced call. (Mirrors upstream's
        // `_end_refresh`.)
        if wasForced || !forceNextRefresh {
            cached = token
        }
        if wasForced {
            forceNextRefresh = false
        }
        pendingRefresh = nil
    }

    private func failRefresh(isAdvisory: Bool) {
        pendingRefresh = nil
        if isAdvisory {
            lastAdvisoryFailureTime = Date()
        }
    }
}
