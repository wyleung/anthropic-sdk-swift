import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaSessionResourcesTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let githubResourceFixture = """
    {
        "id": "resource_gh_01",
        "created_at": "2026-01-15T00:00:00Z",
        "mount_path": "/repo",
        "type": "github_repository",
        "updated_at": "2026-01-15T00:00:00Z",
        "url": "https://github.com/example/repo",
        "checkout": {"name": "main", "type": "branch"}
    }
    """.data(using: .utf8)!

    private static let fileResourceFixture = """
    {
        "id": "resource_file_01",
        "created_at": "2026-01-15T00:00:00Z",
        "file_id": "file_01ABC",
        "mount_path": "/data/report.pdf",
        "type": "file",
        "updated_at": "2026-01-15T00:00:00Z"
    }
    """.data(using: .utf8)!

    private static let memoryStoreResourceFixture = """
    {
        "memory_store_id": "mem_01",
        "type": "memory_store",
        "access": "read_only",
        "description": "Shared notes",
        "instructions": null,
        "mount_path": "/memory",
        "name": "notes"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testRetrieveDecodesGithubRepositoryVariant() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/resources/resource_gh_01")
            return self.jsonResponse(Self.githubResourceFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let resource = try await client.beta.sessions.resources.retrieve(
            "resource_gh_01", sessionId: "session_01ABC"
        )

        guard case .githubRepository(let repo) = resource else {
            return XCTFail("Expected a github_repository resource")
        }
        XCTAssertEqual(repo.url, "https://github.com/example/repo")
        guard case .branch(let branch) = repo.checkout else {
            return XCTFail("Expected a branch checkout")
        }
        XCTAssertEqual(branch.name, "main")
    }

    func testRetrieveDecodesFileVariant() async throws {
        MockURLProtocol.responder = { request in
            self.jsonResponse(Self.fileResourceFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let resource = try await client.beta.sessions.resources.retrieve(
            "resource_file_01", sessionId: "session_01ABC"
        )

        guard case .file(let file) = resource else {
            return XCTFail("Expected a file resource")
        }
        XCTAssertEqual(file.fileId, "file_01ABC")
        XCTAssertEqual(file.mountPath, "/data/report.pdf")
    }

    func testRetrieveDecodesMemoryStoreVariant() async throws {
        MockURLProtocol.responder = { request in
            self.jsonResponse(Self.memoryStoreResourceFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let resource = try await client.beta.sessions.resources.retrieve(
            "resource_mem_01", sessionId: "session_01ABC"
        )

        guard case .memoryStore(let store) = resource else {
            return XCTFail("Expected a memory_store resource")
        }
        XCTAssertEqual(store.memoryStoreId, "mem_01")
        XCTAssertEqual(store.access, .readOnly)
        XCTAssertEqual(store.name, "notes")
    }

    func testUpdateSendsAuthorizationTokenAndDecodesGithubResource() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/resources/resource_gh_01")
            return self.jsonResponse(Self.githubResourceFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let resource = try await client.beta.sessions.resources.update(
            "resource_gh_01", sessionId: "session_01ABC", authorizationToken: "new-token"
        )

        guard case .githubRepository = resource else {
            return XCTFail("Expected a github_repository resource")
        }

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["authorization_token"] as? String, "new-token")
    }

    func testListSendsLimitAndPageAndDecodesForwardCursor() async throws {
        let fixture = """
        {
            "data": [\(String(data: Self.fileResourceFixture, encoding: .utf8)!)],
            "next_page": "page_2"
        }
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/resources")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "10")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "page", value: "page_1")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.sessions.resources.list(
            sessionId: "session_01ABC", limit: 10, page: "page_1"
        )

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.nextPage, "page_2")
        guard case .file = page.data[0] else {
            return XCTFail("Expected a file resource")
        }
    }

    func testDeleteDecodesSessionResourceDeletedConfirmation() async throws {
        let fixture = """
        {"id": "resource_file_01", "type": "session_resource_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/resources/resource_file_01")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.sessions.resources.delete(
            "resource_file_01", sessionId: "session_01ABC"
        )
        XCTAssertEqual(deleted.id, "resource_file_01")
        XCTAssertEqual(deleted.type, "session_resource_deleted")
    }

    func testAddSendsFileResourceParamsAndDecodesFileResource() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/sessions/session_01ABC/resources")
            return self.jsonResponse(Self.fileResourceFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let resource = try await client.beta.sessions.resources.add(
            sessionId: "session_01ABC",
            BetaManagedAgentsFileResourceParams(fileId: "file_01ABC", mountPath: "/data/report.pdf")
        )

        XCTAssertEqual(resource.fileId, "file_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["file_id"] as? String, "file_01ABC")
        XCTAssertEqual(json["mount_path"] as? String, "/data/report.pdf")
    }
}
