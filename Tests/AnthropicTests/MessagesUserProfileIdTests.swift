import XCTest
@testable import Anthropic

/// Regression coverage for Fix #14: `userProfileId` must be sent as the `anthropic-user-profile-id`
/// header, not folded into the request body, mirroring `MessageBatches.create`'s existing pattern.
final class MessagesUserProfileIdTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let messageFixture = """
    {
        "id": "msg_01ABC", "type": "message", "role": "assistant", "model": "claude-opus-5",
        "content": [{"type": "text", "text": "hi"}], "stop_reason": "end_turn", "stop_sequence": null,
        "usage": {"input_tokens": 1, "output_tokens": 1}
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!, statusCode: 200, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsUserProfileIdAsHeaderNotBodyField() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            return self.jsonResponse(Self.messageFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.messages.create(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 16, messages: [.user("hi")]),
            userProfileId: "profile_01"
        )

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-user-profile-id"), "profile_01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["user_profile_id"])
        XCTAssertNil(json["userProfileId"])
    }

    func testStreamSendsUserProfileIdAsHeaderNotBodyField() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, Data())
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.messages.stream(
            MessageCreateParams(model: "claude-opus-5", maxTokens: 16, messages: [.user("hi")]),
            userProfileId: "profile_01"
        )

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-user-profile-id"), "profile_01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["user_profile_id"])
        XCTAssertNil(json["userProfileId"])
    }
}
