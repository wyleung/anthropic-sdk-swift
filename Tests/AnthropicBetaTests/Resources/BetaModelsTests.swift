import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaModelsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private func jsonResponse(_ data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: 200, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testRetrieveDecodesModelInfo() async throws {
        let fixture = """
        {
            "id": "claude-opus-5",
            "created_at": "2026-01-15T00:00:00Z",
            "display_name": "Claude Opus 5",
            "type": "model",
            "allowed_fallback_models": ["claude-sonnet-5"]
        }
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/models/claude-opus-5")
            return self.jsonResponse(fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let model = try await client.beta.models.retrieve("claude-opus-5")

        XCTAssertEqual(model.id, "claude-opus-5")
        XCTAssertEqual(model.displayName, "Claude Opus 5")
        XCTAssertEqual(model.allowedFallbackModels, ["claude-sonnet-5"])
    }

    func testListSendsCursorParams() async throws {
        let fixture = """
        {
            "data": [
                {
                    "id": "claude-opus-5",
                    "created_at": "2026-01-15T00:00:00Z",
                    "display_name": "Claude Opus 5",
                    "type": "model"
                }
            ],
            "has_more": false,
            "first_id": "claude-opus-5",
            "last_id": "claude-opus-5"
        }
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/models")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first { $0.name == "after_id" }?.value, "claude-sonnet-5")
            XCTAssertEqual(query?.first { $0.name == "before_id" }?.value, "claude-haiku-4-5")
            XCTAssertEqual(query?.first { $0.name == "limit" }?.value, "5")
            return self.jsonResponse(fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.models.list(
            afterId: "claude-sonnet-5", beforeId: "claude-haiku-4-5", limit: 5
        )

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.hasMore, false)
    }
}
