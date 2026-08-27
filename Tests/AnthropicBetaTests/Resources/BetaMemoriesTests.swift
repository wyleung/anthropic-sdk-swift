import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaMemoriesTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let memoryFixture = """
    {
        "id": "mem_01ABC",
        "content_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "content_size_bytes": 42,
        "created_at": "2026-01-15T00:00:00Z",
        "memory_store_id": "memstore_01ABC",
        "memory_version_id": "memver_01ABC",
        "path": "/notes/todo",
        "type": "memory",
        "updated_at": "2026-01-15T00:00:00Z",
        "content": null
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBodyQueryAndBetaHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memories")
            return self.jsonResponse(Self.memoryFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let memory = try await client.beta.memoryStores.memories.create(
            memoryStoreId: "memstore_01ABC",
            BetaMemoryCreateParams(content: "", path: "/notes/todo"),
            view: "full"
        )
        XCTAssertEqual(memory.id, "mem_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "agent-memory-2026-07-22")
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "view", value: "full")))
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "")
        XCTAssertEqual(json["path"] as? String, "/notes/todo")
        XCTAssertNil(json["view"])
    }

    func testRetrieveSendsViewAsQueryParam() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memories/mem_01ABC")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "view", value: "basic")))
            return self.jsonResponse(Self.memoryFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let memory = try await client.beta.memoryStores.memories.retrieve(
            "mem_01ABC", memoryStoreId: "memstore_01ABC", view: "basic"
        )
        XCTAssertEqual(memory.path, "/notes/todo")
    }

    func testUpdateOmittedFieldsAreNotSent() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.memoryFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.memoryStores.memories.update(
            "mem_01ABC", memoryStoreId: "memstore_01ABC",
            BetaMemoryUpdateParams(path: "/notes/renamed")
        )

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memories/mem_01ABC")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["path"] as? String, "/notes/renamed")
        XCTAssertNil(json["content"])
        XCTAssertNil(json["precondition"])
    }

    func testUpdateSendsPreconditionInBody() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.memoryFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.memoryStores.memories.update(
            "mem_01ABC", memoryStoreId: "memstore_01ABC",
            BetaMemoryUpdateParams(content: "Updated", precondition: BetaManagedAgentsPreconditionParam(contentSha256: "abc123"))
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "Updated")
        let precondition = try XCTUnwrap(json["precondition"] as? [String: Any])
        XCTAssertEqual(precondition["type"] as? String, "content_sha256")
        XCTAssertEqual(precondition["content_sha256"] as? String, "abc123")
    }

    func testListSendsDepthLimitPathPrefixAndViewQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.memoryFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memories")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "depth", value: "1")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "limit", value: "20")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "path_prefix", value: "/notes/")))
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "view", value: "full")))
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.memoryStores.memories.list(
            memoryStoreId: "memstore_01ABC",
            depth: 1,
            limit: 20,
            pathPrefix: "/notes/",
            view: "full"
        )
        XCTAssertEqual(page.data.count, 1)
        guard case .memory = page.data[0] else {
            return XCTFail("expected .memory variant")
        }
    }

    func testDeleteSendsExpectedContentSha256QueryParam() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/memory_stores/memstore_01ABC/memories/mem_01ABC")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertTrue(components.queryItems!.contains(URLQueryItem(name: "expected_content_sha256", value: "abc123")))
            return self.jsonResponse("""
            {"id": "mem_01ABC", "type": "memory_deleted"}
            """.data(using: .utf8)!)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.beta.memoryStores.memories.delete(
            "mem_01ABC", memoryStoreId: "memstore_01ABC", expectedContentSha256: "abc123"
        )
        XCTAssertEqual(deleted.type, "memory_deleted")
    }
}
