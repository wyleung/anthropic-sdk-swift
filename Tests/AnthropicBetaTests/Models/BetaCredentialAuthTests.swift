import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaCredentialAuthTests: XCTestCase {
    // MARK: - Response decode + round trip

    func testEnvironmentVariableAuthResponseDecodesWithoutSecretValue() throws {
        let fixture = """
        {
            "injection_location": {"body": true, "header": false},
            "networking": {"type": "unrestricted"},
            "secret_name": "API_KEY",
            "type": "environment_variable"
        }
        """.data(using: .utf8)!

        let auth = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: fixture)
        guard case .environmentVariable(let value) = auth else {
            return XCTFail("Expected an environment_variable auth response")
        }
        XCTAssertEqual(value.secretName, "API_KEY")
        XCTAssertTrue(value.injectionLocation.body)
        XCTAssertFalse(value.injectionLocation.header)
        guard case .unrestricted = value.networking else {
            return XCTFail("Expected unrestricted networking")
        }

        let encoded = try HTTPTransport.encoder.encode(auth)
        let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: encoded)
        XCTAssertEqual(auth, roundTripped)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["secret_value"], "response type has no secretValue field to begin with")
    }

    func testStaticBearerAuthResponseDecodesWithoutToken() throws {
        let fixture = """
        {"mcp_server_url": "https://mcp.example.com", "type": "static_bearer"}
        """.data(using: .utf8)!

        let auth = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: fixture)
        guard case .staticBearer(let value) = auth else {
            return XCTFail("Expected a static_bearer auth response")
        }
        XCTAssertEqual(value.mcpServerUrl, "https://mcp.example.com")

        let encoded = try HTTPTransport.encoder.encode(auth)
        let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: encoded)
        XCTAssertEqual(auth, roundTripped)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["token"], "response type has no token field to begin with")
    }

    func testMCPOAuthAuthResponseDecodesWithRefreshAndWithoutAccessToken() throws {
        let fixture = """
        {
            "mcp_server_url": "https://mcp.example.com",
            "type": "mcp_oauth",
            "expires_at": "2026-02-01T00:00:00Z",
            "refresh": {
                "client_id": "client_123",
                "token_endpoint": "https://auth.example.com/token",
                "token_endpoint_auth": {"type": "client_secret_basic"},
                "resource": null,
                "scope": "mcp:read"
            }
        }
        """.data(using: .utf8)!

        let auth = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: fixture)
        guard case .mcpOAuth(let value) = auth else {
            return XCTFail("Expected an mcp_oauth auth response")
        }
        XCTAssertEqual(value.expiresAt, "2026-02-01T00:00:00Z")
        let refresh = try XCTUnwrap(value.refresh)
        XCTAssertEqual(refresh.clientId, "client_123")
        XCTAssertEqual(refresh.scope, "mcp:read")
        guard case .clientSecretBasic = refresh.tokenEndpointAuth else {
            return XCTFail("Expected client_secret_basic token endpoint auth")
        }

        let encoded = try HTTPTransport.encoder.encode(auth)
        let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: encoded)
        XCTAssertEqual(auth, roundTripped)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["access_token"], "response type has no accessToken field to begin with")
        let refreshJson = try XCTUnwrap(json["refresh"] as? [String: Any])
        XCTAssertNil(refreshJson["refresh_token"], "response refresh type has no refreshToken field to begin with")
        let authJson = try XCTUnwrap(refreshJson["token_endpoint_auth"] as? [String: Any])
        XCTAssertNil(authJson["client_secret"], "basic response has no clientSecret field to begin with")
    }

    func testMCPOAuthAuthResponseDecodesWithoutRefresh() throws {
        let fixture = """
        {"mcp_server_url": "https://mcp.example.com", "type": "mcp_oauth", "expires_at": null, "refresh": null}
        """.data(using: .utf8)!
        let auth = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: fixture)
        guard case .mcpOAuth(let value) = auth else {
            return XCTFail("Expected an mcp_oauth auth response")
        }
        XCTAssertNil(value.expiresAt)
        XCTAssertNil(value.refresh)
    }

    func testCredentialAuthDecodesUnknownVariant() throws {
        let fixture = """
        {"type": "some_future_auth"}
        """.data(using: .utf8)!
        let auth = try HTTPTransport.decoder.decode(BetaManagedAgentsCredentialAuth.self, from: fixture)
        guard case .unknown(let type, _) = auth else {
            return XCTFail("Expected an unknown auth variant")
        }
        XCTAssertEqual(type, "some_future_auth")
    }

    // MARK: - Create params encode

    func testCredentialAuthCreateParamsEncodesAllThreeVariants() throws {
        let environmentVariable = BetaCredentialAuthCreateParams.environmentVariable(
            BetaManagedAgentsEnvironmentVariableCreateParams(
                networking: .unrestricted(BetaManagedAgentsUnrestrictedCredentialNetworkingParams()),
                secretName: "API_KEY",
                secretValue: "s3cr3t"
            )
        )
        var encoded = try HTTPTransport.encoder.encode(environmentVariable)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "environment_variable")
        XCTAssertEqual(json["secret_name"] as? String, "API_KEY")
        XCTAssertEqual(json["secret_value"] as? String, "s3cr3t")

        let staticBearer = BetaCredentialAuthCreateParams.staticBearer(
            BetaManagedAgentsStaticBearerCreateParams(token: "bearer-token", mcpServerUrl: "https://mcp.example.com")
        )
        encoded = try HTTPTransport.encoder.encode(staticBearer)
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "static_bearer")
        XCTAssertEqual(json["token"] as? String, "bearer-token")
        XCTAssertEqual(json["mcp_server_url"] as? String, "https://mcp.example.com")

        let mcpOAuth = BetaCredentialAuthCreateParams.mcpOAuth(
            BetaManagedAgentsMCPOAuthCreateParams(
                accessToken: "access-token",
                mcpServerUrl: "https://mcp.example.com",
                refresh: BetaManagedAgentsMCPOAuthRefreshParams(
                    clientId: "client_123",
                    refreshToken: "refresh-token",
                    tokenEndpoint: "https://auth.example.com/token",
                    tokenEndpointAuth: .clientSecretBasic(
                        BetaManagedAgentsTokenEndpointAuthBasicParam(clientSecret: "shh")
                    )
                )
            )
        )
        encoded = try HTTPTransport.encoder.encode(mcpOAuth)
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "mcp_oauth")
        XCTAssertEqual(json["access_token"] as? String, "access-token")
        let refreshJson = try XCTUnwrap(json["refresh"] as? [String: Any])
        XCTAssertEqual(refreshJson["client_id"] as? String, "client_123")
        XCTAssertEqual(refreshJson["refresh_token"] as? String, "refresh-token")
        let authJson = try XCTUnwrap(refreshJson["token_endpoint_auth"] as? [String: Any])
        XCTAssertEqual(authJson["type"] as? String, "client_secret_basic")
        XCTAssertEqual(authJson["client_secret"] as? String, "shh")
    }

    func testCredentialAuthUpdateParamsOmitsUnsetFields() throws {
        let update = BetaCredentialAuthUpdateParams.staticBearer(
            BetaManagedAgentsStaticBearerUpdateParams(token: "new-token")
        )
        let encoded = try HTTPTransport.encoder.encode(update)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "static_bearer")
        XCTAssertEqual(json["token"] as? String, "new-token")
        XCTAssertNil(json["mcp_server_url"], "mcpServerUrl is immutable and has no update field")
    }

    // MARK: - CredentialNetworkingParams union

    func testCredentialNetworkingParamsEncodesBothVariants() throws {
        let unrestricted = BetaManagedAgentsCredentialNetworkingParams.unrestricted(
            BetaManagedAgentsUnrestrictedCredentialNetworkingParams()
        )
        var encoded = try HTTPTransport.encoder.encode(unrestricted)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "unrestricted")

        let limited = BetaManagedAgentsCredentialNetworkingParams.limited(
            BetaManagedAgentsLimitedCredentialNetworkingParams(allowedHosts: ["api.example.com", "*.internal.example.com"])
        )
        encoded = try HTTPTransport.encoder.encode(limited)
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "limited")
        XCTAssertEqual(json["allowed_hosts"] as? [String], ["api.example.com", "*.internal.example.com"])
    }

    // MARK: - TokenEndpointAuth 3-variant response + the none-has-no-update asymmetry

    func testTokenEndpointAuthResponseDecodesAllThreeVariants() throws {
        for type in ["none", "client_secret_basic", "client_secret_post"] {
            let fixture = "{\"type\": \"\(type)\"}".data(using: .utf8)!
            let auth = try HTTPTransport.decoder.decode(BetaManagedAgentsTokenEndpointAuthResponse.self, from: fixture)
            let encoded = try HTTPTransport.encoder.encode(auth)
            let roundTripped = try HTTPTransport.decoder.decode(BetaManagedAgentsTokenEndpointAuthResponse.self, from: encoded)
            XCTAssertEqual(auth, roundTripped, "round trip failed for \(type)")
        }
    }

    func testTokenEndpointAuthUpdateParamHasOnlyTwoVariants() throws {
        // BetaManagedAgentsTokenEndpointAuthUpdateParam has no `.none` case at all -- the Python SDK
        // has no `beta_managed_agents_token_endpoint_auth_none_update_param.py`, so a refresh
        // configured with `none` auth cannot be changed to/from `none` via update. This is enforced
        // at compile time (the case doesn't exist); this test just exercises the 2 that do.
        let basic = BetaManagedAgentsTokenEndpointAuthUpdateParam.clientSecretBasic(
            BetaManagedAgentsTokenEndpointAuthBasicUpdateParam(clientSecret: "new-secret")
        )
        var encoded = try HTTPTransport.encoder.encode(basic)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "client_secret_basic")
        XCTAssertEqual(json["client_secret"] as? String, "new-secret")

        let post = BetaManagedAgentsTokenEndpointAuthUpdateParam.clientSecretPost(
            BetaManagedAgentsTokenEndpointAuthPostUpdateParam(clientSecret: "new-secret")
        )
        encoded = try HTTPTransport.encoder.encode(post)
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "client_secret_post")
    }
}
