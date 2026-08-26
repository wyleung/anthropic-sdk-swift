import XCTest
@testable import Anthropic

final class MessageBatchesTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let batchFixture = """
    {
        "id": "msgbatch_01ABC",
        "archived_at": null,
        "cancel_initiated_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "ended_at": null,
        "expires_at": "2026-01-16T00:00:00Z",
        "processing_status": "in_progress",
        "request_counts": {
            "canceled": 0, "errored": 0, "expired": 0, "processing": 1, "succeeded": 0
        },
        "results_url": null,
        "type": "message_batch"
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: status, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testCreateSendsBodyAndUserProfileHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/messages/batches")
            return self.jsonResponse(Self.batchFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let batch = try await client.messages.batches.create(
            requests: [
                .init(
                    customId: "req-1",
                    params: MessageCreateParams(model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")])
                )
            ],
            userProfileId: "profile_01"
        )

        XCTAssertEqual(batch.id, "msgbatch_01ABC")
        XCTAssertEqual(batch.processingStatus, .inProgress)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-user-profile-id"), "profile_01")

        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let requests = try XCTUnwrap(json["requests"] as? [[String: Any]])
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?["custom_id"] as? String, "req-1")
        let params = try XCTUnwrap(requests.first?["params"] as? [String: Any])
        XCTAssertEqual(params["model"] as? String, "claude-opus-5")
        XCTAssertNil(json["user_profile_id"])
    }

    func testRetrieveDecodesBatch() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/messages/batches/msgbatch_01ABC")
            return self.jsonResponse(Self.batchFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let batch = try await client.messages.batches.retrieve("msgbatch_01ABC")
        XCTAssertEqual(batch.requestCounts.processing, 1)
    }

    func testListDecodesPage() async throws {
        let fixture = """
        {"data": [\(String(data: Self.batchFixture, encoding: .utf8)!)], "has_more": false, "first_id": null, "last_id": null}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/messages/batches")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.messages.batches.list(limit: 20)
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.hasMore, false)
    }

    func testDeleteDecodesDeletedBatch() async throws {
        let fixture = """
        {"id": "msgbatch_01ABC", "type": "message_batch_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/messages/batches/msgbatch_01ABC")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.messages.batches.delete("msgbatch_01ABC")
        XCTAssertEqual(deleted.type, "message_batch_deleted")
    }

    func testCancelPostsToCancelPath() async throws {
        let canceling = String(data: Self.batchFixture, encoding: .utf8)!
            .replacingOccurrences(of: "\"in_progress\"", with: "\"canceling\"")
            .data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/messages/batches/msgbatch_01ABC/cancel")
            return self.jsonResponse(canceling)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let batch = try await client.messages.batches.cancel("msgbatch_01ABC")
        XCTAssertEqual(batch.processingStatus, .canceling)
    }

    func testResultsSplitsJSONLIntoTypedResults() async throws {
        let finished = """
        {
            "id": "msgbatch_01ABC",
            "archived_at": null,
            "cancel_initiated_at": null,
            "created_at": "2026-01-15T00:00:00Z",
            "ended_at": "2026-01-15T01:00:00Z",
            "expires_at": "2026-01-16T00:00:00Z",
            "processing_status": "ended",
            "request_counts": {
                "canceled": 0, "errored": 1, "expired": 0, "processing": 0, "succeeded": 1
            },
            "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_01ABC/results",
            "type": "message_batch"
        }
        """.data(using: .utf8)!

        let succeededLine = """
        {"custom_id": "req-1", "result": {"type": "succeeded", "message": \
        {"id": "msg_1", "type": "message", "role": "assistant", "model": "claude-opus-5", \
        "content": [{"type": "text", "text": "hi"}], "stop_reason": "end_turn", "stop_sequence": null, \
        "usage": {"input_tokens": 1, "output_tokens": 1}}}}
        """
        let erroredLine = """
        {"custom_id": "req-2", "result": {"type": "errored", "error": \
        {"type": "error", "request_id": null, \
        "error": {"type": "invalid_request_error", "message": "bad input"}}}}
        """
        let jsonl = "\(succeededLine)\n\(erroredLine)\n".data(using: .utf8)!

        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            if request.url?.path == "/v1/messages/batches/msgbatch_01ABC" {
                return self.jsonResponse(finished)
            }
            XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages/batches/msgbatch_01ABC/results")
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/binary"]
            )!
            return (response, jsonl)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let results = try await client.messages.batches.results("msgbatch_01ABC")

        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].customId, "req-1")
        guard case .succeeded(let succeeded) = results[0].result else {
            return XCTFail("Expected a succeeded result")
        }
        XCTAssertEqual(succeeded.message.id, "msg_1")

        XCTAssertEqual(results[1].customId, "req-2")
        guard case .errored(let errored) = results[1].result else {
            return XCTFail("Expected an errored result")
        }
        XCTAssertEqual(
            errored.error.error,
            .invalidRequest(InvalidRequestError(message: "bad input", type: "invalid_request_error"))
        )
    }

    func testResultsThrowsWhenNoResultsUrl() async throws {
        MockURLProtocol.responder = { _ in self.jsonResponse(Self.batchFixture) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())

        do {
            _ = try await client.messages.batches.results("msgbatch_01ABC")
            XCTFail("Expected AnthropicError.responseValidation")
        } catch AnthropicError.responseValidation(let message, _) {
            XCTAssertTrue(message.contains("msgbatch_01ABC"))
        }
    }
}
