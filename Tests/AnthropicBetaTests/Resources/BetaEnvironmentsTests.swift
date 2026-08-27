import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaEnvironmentsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let cloudFixture = """
    {
        "id": "env_01ABC",
        "archived_at": null,
        "config": {
            "type": "cloud",
            "networking": {
                "type": "limited",
                "allow_mcp_servers": true,
                "allow_package_managers": false,
                "allowed_hosts": ["example.com"]
            },
            "packages": {"apt": [], "cargo": [], "gem": [], "go": [], "npm": ["left-pad"], "pip": [], "type": "packages"}
        },
        "created_at": "2026-01-15T00:00:00Z",
        "description": "test env",
        "metadata": {"team": "platform"},
        "name": "My Env",
        "type": "environment",
        "updated_at": "2026-01-15T00:00:00Z",
        "scope": null
    }
    """.data(using: .utf8)!

    private static let selfHostedFixture = """
    {
        "id": "env_02DEF",
        "archived_at": null,
        "config": {"type": "self_hosted"},
        "created_at": "2026-01-15T00:00:00Z",
        "description": null,
        "metadata": {},
        "name": "Self hosted env",
        "type": "environment",
        "updated_at": "2026-01-15T00:00:00Z",
        "scope": "account"
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
            XCTAssertEqual(request.url?.path, "/v1/environments")
            return self.jsonResponse(Self.cloudFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let environment = try await client.beta.environments.create(
            BetaEnvironmentCreateParams(
                name: "My Env",
                config: .cloud(
                    BetaCloudConfigParams(
                        networking: .limited(BetaLimitedNetworkParams(allowMcpServers: true, allowedHosts: ["example.com"])),
                        packages: BetaPackagesParams(npm: ["left-pad"])
                    )
                ),
                description: "test env",
                metadata: ["team": "platform"]
            )
        )

        XCTAssertEqual(environment.id, "env_01ABC")
        guard case .cloud(let cloud) = environment.config else {
            return XCTFail("Expected a cloud config")
        }
        guard case .limited(let limited) = cloud.networking else {
            return XCTFail("Expected limited networking")
        }
        XCTAssertEqual(limited.allowMcpServers, true)
        XCTAssertEqual(cloud.packages.npm, ["left-pad"])

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "managed-agents-2026-04-01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "My Env")
        let config = try XCTUnwrap(json["config"] as? [String: Any])
        XCTAssertEqual(config["type"] as? String, "cloud")
    }

    func testRetrieveDecodesSelfHostedEnvironment() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/environments/env_02DEF")
            return self.jsonResponse(Self.selfHostedFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let environment = try await client.beta.environments.retrieve("env_02DEF")
        XCTAssertEqual(environment.scope, .account)
        guard case .selfHosted = environment.config else {
            return XCTFail("Expected a self-hosted config")
        }
    }

    func testUpdateOmittedDescriptionIsNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.cloudFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.environments.update("env_01ABC", BetaEnvironmentUpdateParams(name: "Renamed"))

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["description"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["config"])
    }

    func testUpdateExplicitNullDescriptionClearsAndMetadataPatchesPerKey() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.cloudFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.environments.update(
            "env_01ABC",
            BetaEnvironmentUpdateParams(
                description: .some(nil),
                metadata: ["old_key": nil, "new_key": "value"]
            )
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertTrue(json.keys.contains("description"))
        XCTAssertTrue(json["description"] is NSNull)
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertTrue(metadata["old_key"] is NSNull)
        XCTAssertEqual(metadata["new_key"] as? String, "value")
    }

    func testListDecodesPageCursor() async throws {
        let fixture = """
        {"data": [\(String(data: Self.cloudFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/environments")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "true")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "10")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.environments.list(includeArchived: true, limit: 10)
        XCTAssertEqual(page.data.count, 1)
        XCTAssertNil(page.nextPage)
    }

    func testDeleteDecodesDeleteResponse() async throws {
        let fixture = """
        {"id": "env_01ABC", "type": "environment_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.environments.delete("env_01ABC")
        XCTAssertEqual(deleted.type, "environment_deleted")
    }

    func testArchivePostsToArchivePath() async throws {
        let archived = String(data: Self.cloudFixture, encoding: .utf8)!
            .replacingOccurrences(of: "\"archived_at\": null", with: "\"archived_at\": \"2026-01-16T00:00:00Z\"")
            .data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/environments/env_01ABC/archive")
            return self.jsonResponse(archived)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let environment = try await client.beta.environments.archive("env_01ABC")
        XCTAssertEqual(environment.archivedAt, "2026-01-16T00:00:00Z")
    }
}
