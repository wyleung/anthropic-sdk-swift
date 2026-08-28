import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaSessionThreadEventsTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    func testListSendsPaginationParamsAgainstThreadPath() async throws {
        let fixture = """
        {
            "data": [
                {"id": "evt_end", "type": "session.status_terminated", "processed_at": "2026-01-01T00:00:01Z"}
            ],
            "next_page": "cursor-2"
        }
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/sess_1/threads/thread_1/events")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first { $0.name == "limit" }?.value, "5")
            XCTAssertEqual(query?.first { $0.name == "page" }?.value, "cursor-1")
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            return (response, fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.beta.sessions.threads.events.list(
            "thread_1", sessionId: "sess_1", limit: 5, page: "cursor-1"
        )

        XCTAssertEqual(page.nextPage, "cursor-2")
        let item = try XCTUnwrap(page.data.first)
        guard case .sessionStatusTerminated(let event) = item else {
            return XCTFail("expected sessionStatusTerminated, got \(item)")
        }
        XCTAssertEqual(event.id, "evt_end")
    }

    func testStreamHitsThreadStreamPathAndTranslatesEvents() async throws {
        let sseBody = (
            "event: session.status_terminated\n"
                + #"data: {"id":"evt_end","type":"session.status_terminated","processed_at":"2026-01-01T00:00:01Z"}"#
                + "\n\n"
        ).data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/sess_1/threads/thread_1/stream")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.filter { $0.name == "event_deltas[]" }.map(\.value), ["agent.message"])
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "text/event-stream"]
            )!
            return (response, sseBody)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let stream = try await client.beta.sessions.threads.events.stream(
            "thread_1", sessionId: "sess_1", eventDeltas: ["agent.message"]
        )

        var received: [BetaManagedAgentsStreamSessionThreadEvents] = []
        for try await event in stream {
            received.append(event)
        }

        XCTAssertEqual(received.count, 1)
        guard case .sessionStatusTerminated(let event) = received[0] else {
            return XCTFail("expected sessionStatusTerminated, got \(received[0])")
        }
        XCTAssertEqual(event.id, "evt_end")
    }
}
