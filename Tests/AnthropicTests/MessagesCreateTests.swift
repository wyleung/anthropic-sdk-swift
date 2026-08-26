import XCTest
@testable import Anthropic

final class MessagesCreateTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    func testCreateDecodesMessage() async throws {
        let fixture = """
        {
            "id": "msg_01ABC",
            "type": "message",
            "role": "assistant",
            "model": "claude-opus-5",
            "content": [
                {"type": "text", "text": "Hello there!"}
            ],
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "usage": {
                "input_tokens": 12,
                "output_tokens": 5
            }
        }
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let message = try await client.messages.create(
            MessageCreateParams(
                model: "claude-opus-5",
                maxTokens: 256,
                messages: [.user("Hi Claude")]
            )
        )

        XCTAssertEqual(message.id, "msg_01ABC")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.stopReason, .endTurn)
        XCTAssertEqual(message.usage.inputTokens, 12)
        XCTAssertEqual(message.usage.outputTokens, 5)

        guard case .text(let block) = message.content.first else {
            return XCTFail("Expected a text content block")
        }
        XCTAssertEqual(block.text, "Hello there!")
    }

    func testCreateThrowsTypedErrorOnFailureStatus() async throws {
        let fixture = """
        {"type": "error", "error": {"type": "invalid_request_error", "message": "model: field required"}}
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())

        do {
            _ = try await client.messages.create(
                MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
            )
            XCTFail("Expected AnthropicError.badRequest")
        } catch AnthropicError.badRequest(let detail) {
            XCTAssertEqual(detail.statusCode, 400)
            XCTAssertEqual(detail.type, "invalid_request_error")
        }
    }
}
