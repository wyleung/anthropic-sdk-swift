import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Beta resources share GA's `HTTPTransport`, so its empty-path-segment guard must cover them too --
/// including the nested Managed Agents resources, where the empty id can sit mid-path.
final class BetaEmptyPathIdTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private func assertRejectedBeforeAnyRequest(
        file: StaticString = #filePath, line: UInt = #line,
        _ call: (AnthropicClient) async throws -> Void
    ) async {
        var requestCount = 0
        MockURLProtocol.responder = { request in
            requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        do {
            try await call(client)
            XCTFail("expected AnthropicError.invalidArgument", file: file, line: line)
        } catch AnthropicError.invalidArgument {
            // expected
        } catch {
            XCTFail("expected AnthropicError.invalidArgument, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(requestCount, 0, "an empty id must never reach the network", file: file, line: line)
    }

    func testEmptyIdIsRejectedBeforeSendingOnBetaResources() async {
        await assertRejectedBeforeAnyRequest { _ = try await $0.beta.files.delete("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.beta.files.retrieveMetadata("") }
    }

    func testEmptyIdInANestedManagedAgentsPathIsRejected() async {
        await assertRejectedBeforeAnyRequest {
            _ = try await $0.beta.sessions.resources.retrieve("res_1", sessionId: "")
        }
        await assertRejectedBeforeAnyRequest {
            _ = try await $0.beta.sessions.resources.retrieve("", sessionId: "sesn_1")
        }
    }
}
