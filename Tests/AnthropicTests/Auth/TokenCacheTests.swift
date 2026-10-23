import XCTest
@testable import Anthropic

final class TokenCacheTests: XCTestCase {
    func testReturnsCachedTokenWithoutCallingProviderWhenFresh() async throws {
        let cache = TokenCache()
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "fresh", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })

        let result = try await cache.token(provider: { _ in
            XCTFail("provider should not be called while the cached token is well within its lifetime")
            throw AnthropicError.responseValidation(message: "unexpected", body: nil)
        })
        XCTAssertEqual(result.accessToken, "fresh")
    }

    func testReturnsTokenImmediatelyWhenNoExpiryIsTracked() async throws {
        let cache = TokenCache()
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "no-expiry", expiresAt: nil, refreshToken: nil)
        })

        let result = try await cache.token(provider: { _ in
            XCTFail("a token with no tracked expiry is never considered stale")
            throw AnthropicError.responseValidation(message: "unexpected", body: nil)
        })
        XCTAssertEqual(result.accessToken, "no-expiry")
    }

    func testAdvisoryWindowReturnsStaleTokenAndRefreshesInBackground() async throws {
        let cache = TokenCache()
        // Prime the cache with a token inside the advisory window (30s < remaining <= 120s), so the
        // *next* call takes the "serve stale immediately, refresh in the background" path.
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "initial", expiresAt: Date().addingTimeInterval(100), refreshToken: nil)
        })

        let counter = Counter()
        let refreshStarted = Signal()
        let secondCallResult = try await cache.token(provider: { _ in
            await counter.increment()
            await refreshStarted.fire()
            return AccessToken(accessToken: "refreshed", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })
        // The stale token must come back immediately, without waiting on the background refresh.
        XCTAssertEqual(secondCallResult.accessToken, "initial")

        await refreshStarted.wait()

        // The provider returning is not the refresh landing: `completeRefresh` is a later actor hop.
        let thirdCallResult = try await tokenServedByCache(cache, waitingFor: "refreshed")
        XCTAssertEqual(thirdCallResult.accessToken, "refreshed")
        let countAfterBackgroundRefresh = await counter.count
        XCTAssertEqual(countAfterBackgroundRefresh, 1)
    }

    func testAdvisoryWindowDoesNotStartASecondBackgroundRefreshWhileOneIsPending() async throws {
        let cache = TokenCache()
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "initial", expiresAt: Date().addingTimeInterval(100), refreshToken: nil)
        })

        let counter = Counter()
        let refreshStarted = Signal()
        let releaseRefresh = Signal()
        // Like `testAdvisoryWindowReturnsStaleTokenAndRefreshesInBackground`, the call that *starts*
        // the background refresh also just serves the still-cached stale token immediately -- it does
        // not itself wait on the refresh it kicked off.
        let firstResult = try await cache.token(provider: { _ in
            await counter.increment()
            await refreshStarted.fire()
            await releaseRefresh.wait()
            return AccessToken(accessToken: "refreshed", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })
        XCTAssertEqual(firstResult.accessToken, "initial")

        await refreshStarted.wait()

        let secondResult = try await cache.token(provider: { _ in
            XCTFail("a second background refresh should not start while one is already pending")
            throw AnthropicError.responseValidation(message: "unexpected", body: nil)
        })
        XCTAssertEqual(secondResult.accessToken, "initial")

        await releaseRefresh.fire()

        let thirdResult = try await tokenServedByCache(cache, waitingFor: "refreshed")
        XCTAssertEqual(thirdResult.accessToken, "refreshed")
        let finalCount = await counter.count
        XCTAssertEqual(finalCount, 1)
    }

    func testMandatoryWindowBlocksUntilRefreshCompletes() async throws {
        let cache = TokenCache()
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "about-to-expire", expiresAt: Date().addingTimeInterval(20), refreshToken: nil)
        })

        let result = try await cache.token(provider: { _ in
            AccessToken(accessToken: "renewed", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })
        XCTAssertEqual(result.accessToken, "renewed")
    }

    func testInvalidateForcesAFreshMandatoryRefresh() async throws {
        let cache = TokenCache()
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "fresh", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })
        await cache.invalidate()

        let counter = Counter()
        let result = try await cache.token(provider: { _ in
            await counter.increment()
            return AccessToken(accessToken: "renewed", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })
        XCTAssertEqual(result.accessToken, "renewed")
        let finalCount = await counter.count
        XCTAssertEqual(finalCount, 1)
    }

    /// A 401 invalidates the cache while a background refresh that started earlier is still running. That
    /// refresh was not forced, so with an on-disk provider it may have re-read the very token the server
    /// just rejected; caching it would make the retry (and every request after it) fail again.
    func testRefreshAlreadyInFlightWhenTheCacheIsInvalidatedIsNotCached() async throws {
        let cache = TokenCache()
        _ = try await cache.token(provider: { _ in
            AccessToken(accessToken: "old", expiresAt: Date().addingTimeInterval(100), refreshToken: nil)
        })
        let refreshStarted = Signal()
        let releaseRefresh = Signal()
        // Inside the advisory window: serves "old" and starts an unforced background refresh.
        let started = try await cache.token(provider: { _ in
            await refreshStarted.fire()
            await releaseRefresh.wait()
            return AccessToken(accessToken: "rejected", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
        })
        XCTAssertEqual(started.accessToken, "old")
        await refreshStarted.wait()

        await cache.invalidate()
        await releaseRefresh.fire()

        // Whichever way the race falls, a caller may be handed "rejected" once (by joining the in-flight
        // refresh), but it must never be served from the cache afterwards.
        let forced = Flags()
        var served = AccessToken(accessToken: "", expiresAt: nil, refreshToken: nil)
        let deadline = Date().addingTimeInterval(3)
        repeat {
            served = try await cache.token(provider: { force in
                await forced.record(force)
                return AccessToken(accessToken: "fresh", expiresAt: Date().addingTimeInterval(500), refreshToken: nil)
            })
            if served.accessToken == "fresh" { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        } while Date() < deadline

        XCTAssertEqual(served.accessToken, "fresh", "the rejected token was cached over the invalidation")
        let forcedCalls = await forced.values
        XCTAssertEqual(forcedCalls, [true], "the refresh after an invalidation must be forced")
    }

    func testWaiterJoiningAFailedRefreshBecomesANewLeaderRatherThanPropagatingTheFailure() async throws {
        let cache = TokenCache()
        let counter = Counter()
        let providerStarted = Signal()
        let releaseLeader = Signal()
        let provider: @Sendable (Bool) async throws -> AccessToken = { _ in
            let attempt = await counter.incrementAndGet()
            if attempt == 1 {
                await providerStarted.fire()
                await releaseLeader.wait()
                throw AnthropicError.responseValidation(message: "boom", body: nil)
            }
            return AccessToken(accessToken: "recovered", expiresAt: nil, refreshToken: nil)
        }

        let leaderTask = Task { try await cache.token(provider: provider) }
        await providerStarted.wait()

        // At this point `pendingRefresh` is set but the leader's provider call is blocked on
        // `releaseLeader`, so the waiter is guaranteed to join the in-flight refresh below.
        let waiterTask = Task { try await cache.token(provider: provider) }
        // Nothing observable says the waiter has joined yet, so give it a best-effort head start.
        // Either order ends the same way (a late waiter simply becomes the leader itself), so this
        // can only change which path is exercised, never the outcome.
        await Task.yield()
        await Task.yield()

        await releaseLeader.fire()

        do {
            _ = try await leaderTask.value
            XCTFail("the leader call should propagate the provider's own failure")
        } catch {
            // expected: the leader never retries on its own failure.
        }

        let waiterResult = try await waiterTask.value
        XCTAssertEqual(waiterResult.accessToken, "recovered")
        let finalCount = await counter.count
        XCTAssertEqual(finalCount, 2)
    }
}

/// Polls `cache` until it serves a token whose `accessToken` is `expected`, or `timeout` passes (then
/// it returns whatever it last served, so the caller's assertion reports the mismatch).
///
/// A background refresh finishes on its own `Task`, so no fixed number of `Task.yield()`s guarantees
/// it has landed; observing the cache removes the guess. Every poll hands the cache a provider that
/// must never run -- the refresh being awaited is either still pending or already stored -- so a call
/// to it means a second refresh was wrongly started, which fails the test.
private func tokenServedByCache(
    _ cache: TokenCache,
    waitingFor expected: String,
    timeout: TimeInterval = 10,
    file: StaticString = #filePath,
    line: UInt = #line
) async throws -> AccessToken {
    let strayProviderCalls = Counter()
    let deadline = Date().addingTimeInterval(timeout)
    var served: AccessToken
    repeat {
        served = try await cache.token(provider: { _ in
            await strayProviderCalls.increment()
            return AccessToken(accessToken: "stray-provider-call", expiresAt: nil, refreshToken: nil)
        })
        if served.accessToken == expected { break }
        try await Task.sleep(nanoseconds: 5_000_000)
    } while Date() < deadline
    let strayCount = await strayProviderCalls.count
    XCTAssertEqual(strayCount, 0, "a second refresh was started while one was already in flight or stored", file: file, line: line)
    return served
}

private actor Flags {
    private(set) var values: [Bool] = []

    func record(_ value: Bool) {
        values.append(value)
    }
}

private actor Counter {
    private(set) var count = 0

    func increment() {
        count += 1
    }

    func incrementAndGet() -> Int {
        count += 1
        return count
    }
}

/// A single-fire async gate: any number of `wait()` callers suspend until `fire()` is called once
/// (a no-op on subsequent calls), letting tests pin down interleaving between concurrent actor
/// calls without resorting to timing-based sleeps.
private actor Signal {
    private var fired = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if fired { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func fire() {
        guard !fired else { return }
        fired = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}
