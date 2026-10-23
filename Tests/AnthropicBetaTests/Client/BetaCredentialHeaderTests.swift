import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// A Bearer provider that, like the OAuth-backed ones (`user_oauth` profiles, workload identity
/// federation), marks its requests with the `oauth-2025-04-20` beta flag through `extraHeaders()`.
private struct OAuthMarkerProvider: CredentialProvider {
    func authHeader() async throws -> (name: String, value: String) { ("authorization", "Bearer oauth-token") }
    func extraHeaders() async throws -> [String: String] { ["anthropic-beta": "oauth-2025-04-20"] }
    func invalidate() async {}
}

/// How credential headers combine with a call's own headers. Python's `AccessTokenAuth._apply` adds the
/// provider's `anthropic-beta` flag to whatever flags the request already carries, de-duplicated by whole
/// flag; a plain overwrite would drop it whenever a Beta call sends `betas:` of its own, and the server
/// would then see an OAuth bearer token without the flag that says so.
final class BetaCredentialHeaderTests: XCTestCase {
    private var client: AnthropicClient?

    override func tearDown() {
        MockURLProtocol.responder = nil
        client = nil
        super.tearDown()
    }

    /// Sends one Beta `count_tokens` call (which also sends its own required beta flag) and returns the
    /// request exactly as it reached the network layer.
    private func sentRequest(
        provider: any CredentialProvider = OAuthMarkerProvider(),
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> URLRequest {
        var captured: URLRequest?
        MockURLProtocol.responder = { request in
            captured = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(#"{"input_tokens": 1}"#.utf8))
        }
        let client = AnthropicClient(authProvider: provider, urlSession: MockURLProtocol.makeSession())
        self.client = client
        _ = try await client.beta.messages.countTokens(
            BetaMessageCountTokensParams(model: "claude-opus-5-5", messages: [.user("Hi")]),
            betas: betas, options: options
        )
        return try XCTUnwrap(captured)
    }

    private func flags(of request: URLRequest) -> [String] {
        (request.value(forHTTPHeaderField: "anthropic-beta") ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func testProviderOAuthMarkerSurvivesTheCallsOwnBetas() async throws {
        let request = try await sentRequest(betas: ["files-api-2025-04-14"])

        let sent = flags(of: request)
        XCTAssertTrue(sent.contains("oauth-2025-04-20"), "the provider's flag was replaced: \(sent)")
        XCTAssertTrue(sent.contains("files-api-2025-04-14"), "the call's own flag was lost: \(sent)")
        XCTAssertEqual(sent.count, Set(sent).count, "no flag may repeat: \(sent)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer oauth-token")
    }

    func testProviderMarkerIsNotRepeatedWhenTheCallAlreadySentIt() async throws {
        let request = try await sentRequest(betas: ["oauth-2025-04-20", "files-api-2025-04-14"])

        XCTAssertEqual(flags(of: request).filter { $0 == "oauth-2025-04-20" }.count, 1)
    }

    func testProviderMarkerIsAddedToAnExplicitBetaHeaderInAnyCasing() async throws {
        let request = try await sentRequest(options: RequestOptions(headers: ["Anthropic-Beta": "my-flag"]))

        let sent = flags(of: request)
        XCTAssertTrue(sent.contains("my-flag") && sent.contains("oauth-2025-04-20"), "\(sent)")
        let names = (request.allHTTPHeaderFields ?? [:]).keys.filter { $0.lowercased() == "anthropic-beta" }
        XCTAssertEqual(names.count, 1, "one header, not one per casing: \(names)")
    }

    func testProviderMarkerAloneWhenTheCallSendsNoBetaFlags() async throws {
        var captured: URLRequest?
        MockURLProtocol.responder = { request in
            captured = request
            let body = #"{"data": [], "has_more": false, "first_id": null, "last_id": null}"#
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }
        let client = AnthropicClient(authProvider: OAuthMarkerProvider(), urlSession: MockURLProtocol.makeSession())
        self.client = client

        _ = try await client.models.list()

        XCTAssertEqual(captured?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    /// Header names are case-insensitive, so a per-call `Authorization` must replace the provider's
    /// `authorization` rather than sit beside it in the dictionary -- where the unordered loop that
    /// applies them would pick the winner arbitrarily.
    func testPerCallAuthorizationInAnyCasingReplacesTheProvidersHeader() async throws {
        for attempt in 0..<20 {
            let request = try await sentRequest(options: RequestOptions(headers: ["Authorization": "Bearer per-call"]))

            let names = (request.allHTTPHeaderFields ?? [:]).keys.filter { $0.lowercased() == "authorization" }
            XCTAssertEqual(names.count, 1, "attempt \(attempt): \(names)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer per-call", "attempt \(attempt)")
        }
    }
}
