import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMemoryVersionsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let versionFixture = """
    {
        "id": "memver_01ABC",
        "created_at": "2026-01-15T00:00:00Z",
        "memory_id": "mem_01ABC",
        "memory_store_id": "memstore_01ABC",
        "operation": "created",
        "type": "memory_version",
        "content": "Buy milk",
        "content_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "content_size_bytes": 8,
        "created_by": {"type": "session_actor", "session_id": "sesn_01ABC"},
        "path": "/notes/todo",
        "redacted_at": null,
        "redacted_by": null
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testRetrieveSendsViewAsQueryParamAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memory_versions/memver_01ABC")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "view", value: "full")))
            return self.jsonResponse(Self.versionFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let version = try await client.beta.memoryStores.memoryVersions.retrieve(
            "memver_01ABC", memoryStoreId: "memstore_01ABC", view: "full"
        )
        XCTAssertEqual(version.id, "memver_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "agent-memory-2026-07-22")
    }

    func testListSendsBracketNotationBoundsAndFilterQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.versionFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memory_versions")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[gte]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[lte]", value: "2026-02-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "memory_id", value: "mem_01ABC")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "operation", value: "created")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.memoryStores.memoryVersions.list(
            memoryStoreId: "memstore_01ABC",
            createdAtGte: "2026-01-01T00:00:00Z",
            createdAtLte: "2026-02-01T00:00:00Z",
            memoryId: "mem_01ABC",
            operation: "created"
        )
        XCTAssertEqual(page.data.count, 1)
    }

    func testRedactPostsToRedactPathAndReturnsRedactedVersion() async throws {
        let redactedFixture = """
        {
            "id": "memver_01ABC",
            "created_at": "2026-01-15T00:00:00Z",
            "memory_id": "mem_01ABC",
            "memory_store_id": "memstore_01ABC",
            "operation": "created",
            "type": "memory_version",
            "content": null,
            "content_sha256": null,
            "content_size_bytes": null,
            "created_by": null,
            "path": null,
            "redacted_at": "2026-03-01T00:00:00Z",
            "redacted_by": {"type": "user_actor", "user_id": "user_01ABC"}
        }
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memory_versions/memver_01ABC/redact")
            return self.jsonResponse(redactedFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let version = try await client.beta.memoryStores.memoryVersions.redact(
            "memver_01ABC", memoryStoreId: "memstore_01ABC"
        )
        XCTAssertNotNil(version.redactedAt)
        XCTAssertNil(version.content)
        XCTAssertNil(version.contentSha256)
        XCTAssertNil(version.contentSizeBytes)
        XCTAssertNil(version.path)
    }
}
