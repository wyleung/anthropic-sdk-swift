import XCTest
@testable import Anthropic

final class ModelsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    func testRetrieveDecodesModelInfo() async throws {
        let fixture = """
        {
            "id": "claude-opus-5",
            "created_at": "2026-01-15T00:00:00Z",
            "display_name": "Claude Opus 5",
            "type": "model",
            "max_input_tokens": 1000000,
            "max_tokens": 64000,
            "capabilities": {
                "batch": {"supported": true},
                "citations": {"supported": true},
                "code_execution": {"supported": true},
                "context_management": {"supported": true},
                "effort": {
                    "supported": true,
                    "low": {"supported": true},
                    "medium": {"supported": true},
                    "high": {"supported": true},
                    "max": {"supported": true}
                },
                "image_input": {"supported": true},
                "pdf_input": {"supported": true},
                "structured_outputs": {"supported": true},
                "thinking": {
                    "supported": true,
                    "types": {
                        "adaptive": {"supported": true},
                        "enabled": {"supported": false}
                    }
                }
            }
        }
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/models/claude-opus-5")
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let model = try await client.models.retrieve("claude-opus-5")

        XCTAssertEqual(model.id, "claude-opus-5")
        XCTAssertEqual(model.displayName, "Claude Opus 5")
        XCTAssertEqual(model.maxInputTokens, 1_000_000)
        XCTAssertEqual(model.capabilities?.effort.supported, true)
        XCTAssertEqual(model.capabilities?.thinking.types.adaptive.supported, true)
        XCTAssertNil(model.capabilities?.contextManagement.compact20260112)
    }

    func testListDecodesPageAndSendsCursorParams() async throws {
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
            "has_more": true,
            "first_id": "claude-opus-5",
            "last_id": "claude-opus-5"
        }
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/models")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first { $0.name == "after_id" }?.value, "claude-sonnet-5")
            XCTAssertEqual(query?.first { $0.name == "limit" }?.value, "10")
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.models.list(afterId: "claude-sonnet-5", limit: 10)

        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data.first?.id, "claude-opus-5")
        XCTAssertEqual(page.hasMore, true)
        XCTAssertEqual(page.lastId, "claude-opus-5")
    }
}
