import XCTest
@testable import Anthropic

/// Regression coverage for `String.asPathComponent`: a caller-supplied id containing `/` or `..`
/// must be percent-encoded rather than introducing an extra path segment when interpolated into
/// a path template like `"v1/files/\(fileId.asPathComponent)"`.
final class PathInjectionTests: XCTestCase {
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

    func testSlashInAnIdIsPercentEncodedNotTreatedAsAPathSeparator() {
        XCTAssertEqual("a/b".asPathComponent, "a%2Fb")
    }

    func testDotDotInAnIdIsPercentEncodedNotTreatedAsAPathTraversal() {
        XCTAssertEqual("../../etc/passwd".asPathComponent, "..%2F..%2Fetc%2Fpasswd")
    }

    func testFilesDeleteEncodesASlashContainingIdAsASinglePathSegment() async throws {
        let maliciousId = "file_1/../../admin"
        MockURLProtocol.responder = { request in
            // A single path segment: no unescaped "/" -- the malicious id must not have split
            // the URL into extra segments (["/", "v1", "files", "<encoded id>"], 4 total).
            XCTAssertEqual(request.url?.path, "/v1/files/file_1%2F..%2F..%2Fadmin")
            XCTAssertEqual(request.url?.pathComponents.count, 4)
            XCTAssertEqual(request.url?.pathComponents.last, "file_1%2F..%2F..%2Fadmin")
            let fixture = #"{"id": "file_1", "type": "file_deleted"}"#.data(using: .utf8)!
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.files.delete(maliciousId)
    }

    // MARK: - empty ids

    /// Runs `call` against a client whose transport counts requests, and asserts it throws
    /// `.invalidArgument` *without* anything reaching the wire.
    private func assertRejectedBeforeAnyRequest(
        file: StaticString = #filePath, line: UInt = #line,
        _ call: (AnthropicClient) async throws -> Void
    ) async {
        var requestCount = 0
        MockURLProtocol.responder = { _ in
            requestCount += 1
            return self.jsonResponse(Data("{}".utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        do {
            try await call(client)
            XCTFail("expected AnthropicError.invalidArgument", file: file, line: line)
        } catch AnthropicError.invalidArgument(let message) {
            XCTAssertTrue(message.contains("non-empty"), message, file: file, line: line)
        } catch {
            XCTFail("expected AnthropicError.invalidArgument, got \(error)", file: file, line: line)
        }
        XCTAssertEqual(requestCount, 0, "an empty id must never reach the network", file: file, line: line)
    }

    func testEmptyIdIsRejectedBeforeSendingAcrossResourceFamilies() async {
        // `files.retrieveMetadata("")` used to request `v1/files/` -- the *list* endpoint.
        await assertRejectedBeforeAnyRequest { _ = try await $0.files.retrieveMetadata("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.files.delete("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.files.download("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.models.retrieve("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.messages.batches.retrieve("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.messages.batches.cancel("") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.skills.retrieve("") }
    }

    func testEmptyIdInTheMiddleOfANestedPathIsRejectedToo() async {
        // `v1/skills//versions/v1` and `v1/skills/skill_1/versions/` both contain an empty segment.
        await assertRejectedBeforeAnyRequest { _ = try await $0.skills.versions.retrieve("v1", skillId: "") }
        await assertRejectedBeforeAnyRequest { _ = try await $0.skills.versions.retrieve("", skillId: "skill_1") }
    }

    func testNonEmptyIdsAndServerSuppliedAbsoluteURLsAreStillSent() async throws {
        var requestedURLs: [String] = []
        MockURLProtocol.responder = { request in
            requestedURLs.append(request.url!.absoluteString)
            return self.jsonResponse(#"{"id": "file_1", "type": "file_deleted"}"#.data(using: .utf8)!)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.files.delete("file_1")
        // `https://` itself contains an empty path segment ("https:" / "" / host) -- absolute URLs,
        // like `MessageBatch.resultsURL`, must be exempt from the empty-segment check.
        _ = try await client.transport.getData(
            path: "https://api.anthropic.com/v1/messages/batches/msgbatch_1/results", accept: nil, options: RequestOptions()
        )
        XCTAssertEqual(requestedURLs, [
            "https://api.anthropic.com/v1/files/file_1",
            "https://api.anthropic.com/v1/messages/batches/msgbatch_1/results",
        ])
    }
}
