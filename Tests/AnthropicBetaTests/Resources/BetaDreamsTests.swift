import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaDreamsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let dreamFixture = """
    {
        "id": "dream_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "ended_at": null,
        "error": null,
        "inputs": [{"memory_store_id": "memstore_01ABC", "type": "memory_store"}],
        "instructions": null,
        "model": {"id": "claude-opus-5"},
        "output_behavior": {"type": "create_new"},
        "outputs": [],
        "session_id": null,
        "status": "pending",
        "type": "dream",
        "usage": {
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0,
            "input_tokens": 0,
            "output_tokens": 0
        }
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
            XCTAssertEqual(request.url?.path, "/v1/dreams")
            return self.jsonResponse(Self.dreamFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let params = BetaDreamCreateParams(
            inputs: [.memoryStore(memoryStoreId: "memstore_01ABC")],
            model: "claude-opus-5"
        )
        let dream = try await client.beta.dreams.create(params)
        XCTAssertEqual(dream.id, "dream_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "dreaming-2026-04-21")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus-5")
    }

    func testRetrieveDecodesDream() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/dreams/dream_01ABC")
            return self.jsonResponse(Self.dreamFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let dream = try await client.beta.dreams.retrieve("dream_01ABC")
        XCTAssertEqual(dream.status, .pending)
    }

    func testListSendsExclusiveBoundsAndRepeatedStatuses() async throws {
        let fixture = """
        {"data": [\(String(data: Self.dreamFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/dreams")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "created_at[gt]", value: "2026-01-01T00:00:00Z")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "created_at[lt]", value: "2026-02-01T00:00:00Z")))
            let statuses = query.filter { $0.name == "statuses[]" }.map(\.value)
            XCTAssertEqual(statuses, ["pending", "running"])
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.dreams.list(
            createdAtGt: "2026-01-01T00:00:00Z",
            createdAtLt: "2026-02-01T00:00:00Z",
            statuses: ["pending", "running"]
        )
        XCTAssertEqual(page.data.count, 1)
    }

    func testArchivePostsToArchivePath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/dreams/dream_01ABC/archive")
            return self.jsonResponse(Self.dreamFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.dreams.archive("dream_01ABC")
    }

    func testCancelPostsToCancelPath() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/dreams/dream_01ABC/cancel")
            return self.jsonResponse(Self.dreamFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.dreams.cancel("dream_01ABC")
    }
}
