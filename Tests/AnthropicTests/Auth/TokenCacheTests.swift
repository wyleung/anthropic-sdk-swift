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
        // Let the actor finish the `completeRefresh` hop that follows the provider returning.
        await Task.yield()
        await Task.yield()

        let countAfterBackgroundRefresh = await counter.count
        XCTAssertEqual(countAfterBackgroundRefresh, 1)
        let thirdCallResult = try await cache.token(provider: { _ in
            XCTFail("provider should not be called again once the cache holds a fresh token")
            throw AnthropicError.responseValidation(message: "unexpected", body: nil)
        })
        XCTAssertEqual(thirdCallResult.accessToken, "refreshed")
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
        await Task.yield()
        await Task.yield()

        let finalCount = await counter.count
        XCTAssertEqual(finalCount, 1)
        let thirdResult = try await cache.token(provider: { _ in
            XCTFail("provider should not be called again once the cache holds the refreshed token")
            throw AnthropicError.responseValidation(message: "unexpected", body: nil)
        })
        XCTAssertEqual(thirdResult.accessToken, "refreshed")
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
