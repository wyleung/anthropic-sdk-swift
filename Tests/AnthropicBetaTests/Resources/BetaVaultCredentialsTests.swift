import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaVaultCredentialsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let credentialFixture = """
    {
        "id": "cred_01ABC",
        "archived_at": null,
        "auth": {"mcp_server_url": "https://mcp.example.com", "type": "static_bearer"},
        "created_at": "2026-01-15T00:00:00Z",
        "metadata": {},
        "type": "vault_credential",
        "updated_at": "2026-01-15T00:00:00Z",
        "vault_id": "vault_01ABC",
        "display_name": null
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBodyAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials")
            return self.jsonResponse(Self.credentialFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let params = BetaCredentialCreateParams(
            auth: .staticBearer(BetaManagedAgentsStaticBearerCreateParams(token: "secret-token", mcpServerUrl: "https://mcp.example.com"))
        )
        let credential = try await client.beta.vaults.credentials.create(vaultId: "vault_01ABC", params)
        XCTAssertEqual(credential.id, "cred_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let auth = try XCTUnwrap(json["auth"] as? [String: Any])
        XCTAssertEqual(auth["token"] as? String, "secret-token")
    }

    func testRetrieveDecodesCredential() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials/cred_01ABC")
            return self.jsonResponse(Self.credentialFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let credential = try await client.beta.vaults.credentials.retrieve("cred_01ABC", vaultId: "vault_01ABC")
        XCTAssertEqual(credential.vaultId, "vault_01ABC")
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.credentialFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.vaults.credentials.update(
            "cred_01ABC", vaultId: "vault_01ABC", BetaCredentialUpdateParams(displayName: "Renamed")
        )

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials/cred_01ABC")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "Renamed")
        XCTAssertNil(json["auth"])
        XCTAssertNil(json["metadata"])
    }

    func testListSendsFiltersAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.credentialFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "true")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.vaults.credentials.list(vaultId: "vault_01ABC", includeArchived: true, limit: 5)
        XCTAssertEqual(page.data.count, 1)
    }

    func testDeleteReturnsDeletedCredential() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials/cred_01ABC")
            return self.jsonResponse("""
            {"id": "cred_01ABC", "type": "vault_credential_deleted"}
            """.data(using: .utf8)!)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.vaults.credentials.delete("cred_01ABC", vaultId: "vault_01ABC")
        XCTAssertEqual(deleted.type, "vault_credential_deleted")
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials/cred_01ABC/archive")
            return self.jsonResponse(Self.credentialFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.vaults.credentials.archive("cred_01ABC", vaultId: "vault_01ABC")
    }

    func testMcpOauthValidatePostsToValidatePathAndDecodesValidation() async throws {
        let fixture = """
        {
            "credential_id": "cred_01ABC",
            "has_refresh_token": false,
            "mcp_probe": null,
            "refresh": null,
            "status": "valid",
            "type": "vault_credential_validation",
            "validated_at": "2026-01-15T00:00:00Z",
            "vault_id": "vault_01ABC"
        }
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/credentials/cred_01ABC/mcp_oauth_validate")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let validation = try await client.beta.vaults.credentials.mcpOauthValidate("cred_01ABC", vaultId: "vault_01ABC")
        XCTAssertEqual(validation.status, .valid)
        XCTAssertEqual(validation.credentialId, "cred_01ABC")
    }
}
