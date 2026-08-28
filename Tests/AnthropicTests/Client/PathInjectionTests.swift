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
}
