import XCTest
@testable import Anthropic

final class OAuthTokenEndpointTests: XCTestCase {
    private let baseURL = URL(string: "https://api.anthropic.com")!

    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    // MARK: - jwt-bearer grant

    func testExchangeJWTBearerSendsExpectedRequestAndDecodesResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            let body = Data(#"{"access_token":"at-123","expires_in":3600,"token_type":"Bearer"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let token = try await OAuthTokenEndpoint.exchangeJWTBearer(
            baseURL: baseURL, assertion: "jwt-assertion", federationRuleId: "rule-1",
            organizationId: "org-1", serviceAccountId: "sa-1", workspaceId: "ws-1",
            urlSession: MockURLProtocol.makeSession()
        )

        XCTAssertEqual(token.accessToken, "at-123")
        XCTAssertNotNil(token.expiresAt)
        XCTAssertNil(token.refreshToken)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/oauth/token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20,oidc-federation-2026-04-01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["grant_type"] as? String, "urn:ietf:params:oauth:grant-type:jwt-bearer")
        XCTAssertEqual(json["assertion"] as? String, "jwt-assertion")
        XCTAssertEqual(json["federation_rule_id"] as? String, "rule-1")
        XCTAssertEqual(json["organization_id"] as? String, "org-1")
        XCTAssertEqual(json["service_account_id"] as? String, "sa-1")
        XCTAssertEqual(json["workspace_id"] as? String, "ws-1")
    }

    func testExchangeJWTBearerOmitsOptionalFieldsWhenNil() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            let body = Data(#"{"access_token":"at-123","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        _ = try await OAuthTokenEndpoint.exchangeJWTBearer(
            baseURL: baseURL, assertion: "jwt-assertion", federationRuleId: "rule-1",
            organizationId: "org-1", serviceAccountId: nil, workspaceId: nil,
            urlSession: MockURLProtocol.makeSession()
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["service_account_id"])
        XCTAssertNil(json["workspace_id"])
    }

    func testExchangeJWTBearerThrowsWhenAssertionExceedsSizeLimit() async throws {
        let oversized = String(repeating: "a", count: OAuthTokenEndpoint.maxAssertionBytes + 1)
        do {
            _ = try await OAuthTokenEndpoint.exchangeJWTBearer(
                baseURL: baseURL, assertion: oversized, federationRuleId: "rule-1",
                organizationId: "org-1", serviceAccountId: nil, workspaceId: nil,
                urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected an error for an over-limit assertion")
        } catch {
            // expected
        }
    }

    func testExchangeJWTBearerThrowsWhenExpiresInIsMissing() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-123"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        do {
            _ = try await OAuthTokenEndpoint.exchangeJWTBearer(
                baseURL: baseURL, assertion: "jwt-assertion", federationRuleId: "rule-1",
                organizationId: "org-1", serviceAccountId: nil, workspaceId: nil,
                urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected an error when expires_in is absent")
        } catch {
            // expected
        }
    }

    func testExchangeJWTBearerMapsNon2xxToAuthenticationErrorWithRedactedBody() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(
                #"{"error":"invalid_grant","error_description":"bad assertion","assertion":"leaked-secret"}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, body)
        }

        do {
            _ = try await OAuthTokenEndpoint.exchangeJWTBearer(
                baseURL: baseURL, assertion: "jwt-assertion", federationRuleId: "rule-1",
                organizationId: "org-1", serviceAccountId: nil, workspaceId: nil,
                urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected a 401 to surface as an error")
        } catch let error as AnthropicError {
            guard case .authentication(let detail) = error else {
                return XCTFail("expected .authentication, got \(error)")
            }
            XCTAssertEqual(detail.type, "invalid_grant")
            XCTAssertTrue(detail.message.contains("bad assertion"))
            if case .object(let fields)? = detail.body {
                XCTAssertNil(fields["assertion"], "the raw request body must not be echoed back in the error")
            } else {
                XCTFail("expected a redacted object body")
            }
        }
    }

    // MARK: - refresh_token grant

    func testExchangeRefreshTokenSendsExpectedRequestAndDecodesResponse() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            let body = Data(#"{"access_token":"at-456","expires_in":7200,"refresh_token":"rt-new"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let token = try await OAuthTokenEndpoint.exchangeRefreshToken(
            baseURL: baseURL, refreshToken: "rt-old", clientId: "client-1",
            urlSession: MockURLProtocol.makeSession()
        )
        XCTAssertEqual(token.accessToken, "at-456")
        XCTAssertEqual(token.refreshToken, "rt-new")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["grant_type"] as? String, "refresh_token")
        XCTAssertEqual(json["refresh_token"] as? String, "rt-old")
        XCTAssertEqual(json["client_id"] as? String, "client-1")
    }

    func testExchangeRefreshTokenDefaultsExpiresInWhenAbsent() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-456"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let before = Date()
        let token = try await OAuthTokenEndpoint.exchangeRefreshToken(
            baseURL: baseURL, refreshToken: "rt-old", clientId: "client-1",
            urlSession: MockURLProtocol.makeSession()
        )
        let expiresAt = try XCTUnwrap(token.expiresAt)
        XCTAssertEqual(expiresAt.timeIntervalSince(before), 3600, accuracy: 5)
    }

    func testExchangeRefreshTokenCarriesForwardTheOldRefreshTokenWhenNotRotated() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-456","expires_in":3600}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let token = try await OAuthTokenEndpoint.exchangeRefreshToken(
            baseURL: baseURL, refreshToken: "rt-old", clientId: "client-1",
            urlSession: MockURLProtocol.makeSession()
        )
        XCTAssertEqual(token.refreshToken, "rt-old")
    }

    func testExchangeRefreshTokenThrowsOnUnexpectedTokenType() async throws {
        MockURLProtocol.responder = { request in
            let body = Data(#"{"access_token":"at-456","expires_in":3600,"token_type":"MAC"}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        do {
            _ = try await OAuthTokenEndpoint.exchangeRefreshToken(
                baseURL: baseURL, refreshToken: "rt-old", clientId: "client-1",
                urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected an error for an unrecognized token_type")
        } catch {
            // expected
        }
    }

    func testExchangeRefreshTokenThrowsOnNonJSONBody() async throws {
        MockURLProtocol.responder = { request in
            let body = Data("not json".utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        do {
            _ = try await OAuthTokenEndpoint.exchangeRefreshToken(
                baseURL: baseURL, refreshToken: "rt-old", clientId: "client-1",
                urlSession: MockURLProtocol.makeSession()
            )
            XCTFail("expected an error for a non-JSON body")
        } catch {
            // expected
        }
    }

    // MARK: - redirects

    /// Answers the token endpoint with a 307 to `leakHost`, and answers `leakHost` with a valid token
    /// -- so a client that follows the redirect both "succeeds" and records the leak.
    private final class RedirectingURLProtocol: URLProtocol {
        static let leakHost = "collector.example"
        static var requestedURLs: [URL] = []
        static var leakedBody: Data?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let url = request.url!
            Self.requestedURLs.append(url)
            if url.host == Self.leakHost {
                Self.leakedBody = request.httpBody ?? request.httpBodyStream.flatMap(Self.drain)
                let body = Data(#"{"access_token":"leaked","expires_in":3600,"token_type":"Bearer"}"#.utf8)
                let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: ok, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            let target = URL(string: "https://\(Self.leakHost)/collect")!
            let redirect = HTTPURLResponse(
                url: url, statusCode: 307, httpVersion: nil, headerFields: ["Location": target.absoluteString]
            )!
            var next = URLRequest(url: target)
            next.httpMethod = request.httpMethod
            next.httpBody = request.httpBody ?? request.httpBodyStream.flatMap(Self.drain)
            client?.urlProtocol(self, wasRedirectedTo: next, redirectResponse: redirect)
            // If the task delegate declines the redirect, URLSession falls back to this response as
            // the final one -- a custom protocol has to supply it, a real network stack does not.
            client?.urlProtocol(self, didReceive: redirect, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        private static func drain(_ stream: InputStream) -> Data {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                data.append(buffer, count: read)
            }
            return data
        }
    }

    func testTokenExchangeDoesNotFollowARedirectSoTheAssertionCannotBeForwarded() async throws {
        RedirectingURLProtocol.requestedURLs = []
        RedirectingURLProtocol.leakedBody = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectingURLProtocol.self]

        do {
            _ = try await OAuthTokenEndpoint.exchangeJWTBearer(
                baseURL: baseURL, assertion: "secret-jwt", federationRuleId: "rule-1",
                organizationId: "org-1", serviceAccountId: nil, workspaceId: nil,
                urlSession: URLSession(configuration: configuration)
            )
            XCTFail("a redirected token exchange must fail, not succeed against the redirect target")
        } catch AnthropicError.authentication(let detail) {
            XCTAssertEqual(detail.statusCode, 307)
        }

        XCTAssertEqual(RedirectingURLProtocol.requestedURLs.map(\.host), ["api.anthropic.com"])
        XCTAssertNil(RedirectingURLProtocol.leakedBody)
    }

    func testRefreshTokenExchangeDoesNotFollowARedirectEither() async throws {
        RedirectingURLProtocol.requestedURLs = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectingURLProtocol.self]

        do {
            _ = try await OAuthTokenEndpoint.exchangeRefreshToken(
                baseURL: baseURL, refreshToken: "secret-refresh", clientId: "client-1",
                urlSession: URLSession(configuration: configuration)
            )
            XCTFail("a redirected refresh must fail")
        } catch AnthropicError.authentication {
            // expected
        }
        XCTAssertEqual(RedirectingURLProtocol.requestedURLs.map(\.host), ["api.anthropic.com"])
    }
}
