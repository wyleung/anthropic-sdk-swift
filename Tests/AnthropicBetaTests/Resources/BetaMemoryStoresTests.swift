import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMemoryStoresTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let memoryStoreFixture = """
    {
        "id": "memstore_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "description": null,
        "metadata": {},
        "name": "User Memory",
        "type": "memory_store",
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
            XCTAssertEqual(request.url?.path, "/v1/memory_stores")
            return self.jsonResponse(Self.memoryStoreFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let store = try await client.beta.memoryStores.create(BetaMemoryStoreCreateParams(name: "User Memory"))
        XCTAssertEqual(store.id, "memstore_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "agent-memory-2026-07-22")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "User Memory")
    }

    func testRetrieveDecodesMemoryStore() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC")
            return self.jsonResponse(Self.memoryStoreFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let store = try await client.beta.memoryStores.retrieve("memstore_01ABC")
        XCTAssertEqual(store.name, "User Memory")
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.memoryStoreFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.memoryStores.update("memstore_01ABC", BetaMemoryStoreUpdateParams(name: "Renamed"))

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "Renamed")
        XCTAssertNil(json["description"])
        XCTAssertNil(json["metadata"])
    }

    func testListSendsInclusiveBoundsAndPagingQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.memoryStoreFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/memory_stores")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[gte]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "created_at[lte]", value: "2026-02-01T00:00:00Z")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "include_archived", value: "true")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "5")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.memoryStores.list(
            createdAtGte: "2026-01-01T00:00:00Z",
            createdAtLte: "2026-02-01T00:00:00Z",
            includeArchived: true,
            limit: 5
        )
        XCTAssertEqual(page.data.count, 1)
    }

    func testDeleteReturnsDeletedMemoryStore() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC")
            return self.jsonResponse("""
            {"id": "memstore_01ABC", "type": "memory_store_deleted"}
            """.data(using: .utf8)!)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.memoryStores.delete("memstore_01ABC")
        XCTAssertEqual(deleted.type, "memory_store_deleted")
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/archive")
            return self.jsonResponse(Self.memoryStoreFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.memoryStores.archive("memstore_01ABC")
    }
}
