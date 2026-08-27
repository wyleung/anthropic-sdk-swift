import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaVaultsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let vaultFixture = """
    {
        "id": "vault_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "display_name": "Production Vault",
        "metadata": {},
        "type": "vault",
        "updated_at": "2026-01-15T00:00:00Z"
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
            XCTAssertEqual(request.url?.path, "/v1/vaults")
            return self.jsonResponse(Self.vaultFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let vault = try await client.beta.vaults.create(BetaVaultCreateParams(displayName: "Production Vault"))
        XCTAssertEqual(vault.id, "vault_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "Production Vault")
    }

    func testRetrieveDecodesVault() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC")
            return self.jsonResponse(Self.vaultFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let vault = try await client.beta.vaults.retrieve("vault_01ABC")
        XCTAssertEqual(vault.displayName, "Production Vault")
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.vaultFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.vaults.update("vault_01ABC", BetaVaultUpdateParams(displayName: "Renamed"))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "Renamed")
        XCTAssertNil(json["metadata"])
    }

    func testListSendsFiltersAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.vaultFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/vaults")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "true")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.vaults.list(includeArchived: true, limit: 5)
        XCTAssertEqual(page.data.count, 1)
    }

    func testDeleteReturnsDeletedVault() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC")
            return self.jsonResponse("""
            {"id": "vault_01ABC", "type": "vault_deleted"}
            """.data(using: .utf8)!)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.vaults.delete("vault_01ABC")
        XCTAssertEqual(deleted.type, "vault_deleted")
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/vaults/vault_01ABC/archive")
            return self.jsonResponse(Self.vaultFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.vaults.archive("vault_01ABC")
    }
}
