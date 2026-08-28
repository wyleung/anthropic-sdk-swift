import XCTest
@testable import Anthropic

/// Regression coverage for `HTTPTransport.withRetries`/`AnthropicError.from(response:body:)`:
/// the `x-should-retry` and `retry-after-ms` response headers must override the default
/// status-code-driven retry policy, and a 401 must trigger exactly one credential invalidation
/// and retry rather than being retried on the normal exponential-backoff budget.
final class HTTPTransportRetryTests: XCTestCase {
    private static let modelFixture = """
    {"id": "claude-opus-5", "created_at": "2026-01-15T00:00:00Z", "display_name": "Claude Opus 5", "type": "model"}
    """.data(using: .utf8)!

    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private func errorResponse(
        url: URL, statusCode: Int, extraHeaders: [String: String] = [:]
    ) -> (HTTPURLResponse, Data) {
        var headers = ["content-type": "application/json"]
        for (key, value) in extraHeaders { headers[key] = value }
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        let body = #"{"error": {"type": "error", "message": "boom"}}"#.data(using: .utf8)!
        return (response, body)
    }

    private func successResponse(url: URL) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
        )!
        return (response, Self.modelFixture)
    }

    func testXShouldRetryTrueOverridesAnOtherwiseNonRetryableStatusCode() async throws {
        let callCount = Locked(0)
        MockURLProtocol.responder = { request in
            let count = callCount.increment()
            if count == 1 {
                // 400 is not in the default retryable set -- without honoring the header this
                // would throw immediately on the first call.
                return self.errorResponse(url: request.url!, statusCode: 400, extraHeaders: ["x-should-retry": "true"])
            }
            return self.successResponse(url: request.url!)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let model = try await client.models.retrieve("claude-opus-5")

        XCTAssertEqual(model.id, "claude-opus-5")
        XCTAssertEqual(callCount.value, 2)
    }

    func testXShouldRetryFalseOverridesAnOtherwiseRetryableStatusCode() async throws {
        let callCount = Locked(0)
        MockURLProtocol.responder = { request in
            callCount.increment()
            // 500 is normally retryable -- the header must suppress that.
            return self.errorResponse(url: request.url!, statusCode: 500, extraHeaders: ["x-should-retry": "false"])
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        do {
            _ = try await client.models.retrieve("claude-opus-5")
            XCTFail("expected an internalServer error")
        } catch AnthropicError.internalServer {
            // expected
        }
        XCTAssertEqual(callCount.value, 1)
    }

    func testRetryAfterMsHeaderIsHonoredInMillisecondsNotSeconds() async throws {
        let callCount = Locked(0)
        MockURLProtocol.responder = { request in
            let count = callCount.increment()
            if count == 1 {
                return self.errorResponse(
                    url: request.url!, statusCode: 429, extraHeaders: ["retry-after-ms": "20"]
                )
            }
            return self.successResponse(url: request.url!)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let start = DispatchTime.now()
        _ = try await client.models.retrieve("claude-opus-5")
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000

        XCTAssertEqual(callCount.value, 2)
        // The default exponential backoff for a first retry is ~0.375-0.5s -- if `retry-after-ms`
        // were misread as seconds (or ignored), this would take far longer than 20ms.
        XCTAssertLessThan(elapsed, 0.3)
    }

    func testAuthenticationErrorInvalidatesCredentialsExactlyOnceAndRetries() async throws {
        let callCount = Locked(0)
        MockURLProtocol.responder = { request in
            let count = callCount.increment()
            if count == 1 {
                return self.errorResponse(url: request.url!, statusCode: 401)
            }
            return self.successResponse(url: request.url!)
        }

        let invalidateCount = Locked(0)
        let provider = CountingInvalidateProvider(invalidateCount: invalidateCount)
        let client = AnthropicClient(authProvider: provider, urlSession: MockURLProtocol.makeSession())

        let model = try await client.models.retrieve("claude-opus-5")

        XCTAssertEqual(model.id, "claude-opus-5")
        XCTAssertEqual(callCount.value, 2)
        XCTAssertEqual(invalidateCount.value, 1)
    }
}

/// Thread-safe counter -- `MockURLProtocol.responder` and the retry loop's `Task.sleep` cross
/// actor/thread boundaries, so a plain `var` capture would be a data race.
private final class Locked: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int

    init(_ value: Int) { _value = value }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
        return _value
    }
}

private struct CountingInvalidateProvider: CredentialProvider {
    let invalidateCount: Locked

    func authHeader() async throws -> (name: String, value: String) {
        ("x-api-key", "test-key")
    }

    func invalidate() async {
        invalidateCount.increment()
    }
}
