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

    // MARK: - 2026-10 lifecycle / line / capability additions

    private func respond(with json: String, assert check: @escaping (URLRequest) -> Void = { _ in }) {
        MockURLProtocol.responder = { request in
            check(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
    }

    func testRetrieveDecodesLifecycleLineAndScheduleFields() async throws {
        respond(with: """
        {
            "id": "claude-sonnet-4-5", "created_at": "2025-09-29T00:00:00Z", "display_name": "Claude Sonnet 4.5",
            "type": "model", "lifecycle": "deprecated", "line": "sonnet",
            "deprecated_at": "2026-09-30T00:00:00Z", "retires_at": "2027-03-01T00:00:00Z"
        }
        """)
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let model = try await client.models.retrieve("claude-sonnet-4-5")

        XCTAssertEqual(model.lifecycle, .deprecated)
        XCTAssertEqual(model.line, .sonnet)
        XCTAssertEqual(model.deprecatedAt, "2026-09-30T00:00:00Z")
        XCTAssertEqual(model.retiresAt, "2027-03-01T00:00:00Z")
    }

    func testActiveModelHasNullScheduleFieldsAndNoLine() async throws {
        respond(with: """
        {
            "id": "claude-opus-5-5", "created_at": "2026-09-22T00:00:00Z", "display_name": "Claude Opus 5.5",
            "type": "model", "lifecycle": "active", "line": null, "deprecated_at": null, "retires_at": null
        }
        """)
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let model = try await client.models.retrieve("claude-opus-5-5")

        XCTAssertEqual(model.lifecycle, .active)
        XCTAssertNil(model.line)
        XCTAssertNil(model.deprecatedAt)
        XCTAssertNil(model.retiresAt)
    }

    func testLifecycleAndLineNewerThanThePortDegradeToUnknownInsteadOfFailingTheList() async throws {
        respond(with: """
        {"data": [{"id": "m", "created_at": "2026-01-01T00:00:00Z", "display_name": "M", "type": "model",
                   "lifecycle": "sunsetting", "line": "oracle"}], "has_more": false}
        """)
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.models.list()

        XCTAssertEqual(page.data.first?.lifecycle, .unknown("sunsetting"))
        XCTAssertEqual(page.data.first?.line, .unknown("oracle"))
    }

    func testCapabilitiesDecodeServerToolsAndTheNewThinkingTypes() async throws {
        respond(with: """
        {
            "id": "claude-opus-5-5", "created_at": "2026-09-22T00:00:00Z", "display_name": "Claude Opus 5.5", "type": "model",
            "capabilities": {
                "batch": {"supported": true}, "citations": {"supported": true},
                "code_execution": {"supported": true}, "context_management": {"supported": true},
                "effort": {"supported": true, "low": {"supported": true}, "medium": {"supported": true},
                           "high": {"supported": true}, "max": {"supported": true}},
                "image_input": {"supported": true}, "pdf_input": {"supported": true},
                "server_tools": {"supported": true, "code_execution": {"supported": true}, "web_search": {"supported": false}},
                "structured_outputs": {"supported": true},
                "thinking": {"supported": true, "types": {
                    "adaptive": {"supported": true}, "between_tools": {"supported": true},
                    "disabled": {"supported": true}, "enabled": {"supported": false}}}
            }
        }
        """)
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let model = try await client.models.retrieve("claude-opus-5-5")
        let capabilities = try XCTUnwrap(model.capabilities)

        XCTAssertEqual(capabilities.serverTools?.supported, true)
        XCTAssertEqual(capabilities.serverTools?.codeExecution.supported, true)
        XCTAssertEqual(capabilities.serverTools?.webSearch.supported, false)
        XCTAssertEqual(capabilities.thinking.types.betweenTools?.supported, true)
        XCTAssertEqual(capabilities.thinking.types.disabled?.supported, true)
    }

    func testListSendsLifecycleAsRepeatedBracketedQueryItems() async throws {
        var seenQuery: String?
        respond(with: #"{"data": [], "has_more": false}"#) { seenQuery = $0.url?.query }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.models.list(lifecycle: ["retired", "active"], limit: 5)

        let items = try XCTUnwrap(seenQuery).split(separator: "&").map(String.init)
        // Python's `qs` is `Querystring(array_format="brackets")`; the brackets may be percent-encoded.
        let decoded = items.map { $0.removingPercentEncoding ?? $0 }
        XCTAssertTrue(decoded.contains("lifecycle[]=retired"), "\(decoded)")
        XCTAssertTrue(decoded.contains("lifecycle[]=active"), "\(decoded)")
        XCTAssertTrue(decoded.contains("limit=5"), "\(decoded)")
    }

    func testListOmitsLifecycleWhenNotGiven() async throws {
        var seenQuery: String? = "sentinel"
        respond(with: #"{"data": [], "has_more": false}"#) { seenQuery = $0.url?.query }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.models.list()
        XCTAssertNil(seenQuery)
    }
}
