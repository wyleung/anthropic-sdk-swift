import XCTest
@testable import Anthropic

/// Regression coverage for `MultipartFormData`'s `Content-Disposition` escaping: a caller-supplied
/// `name`/`filename` containing `"` or CR/LF must not be able to inject an extra header or part
/// boundary into the encoded body.
final class MultipartFormDataTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    func testFilenameWithCRLFCannotInjectAnExtraHeaderLine() {
        var form = MultipartFormData()
        form.addFile(
            name: "file", filename: "evil\".txt\r\nX-Evil-Header: 1", contentType: "text/plain",
            data: Data("hi".utf8)
        )
        let body = String(decoding: form.encode(), as: UTF8.self)

        // The CR/LF inside the filename must be gone -- if it survived, this substring would be
        // its own header line rather than folded into the filename value.
        XCTAssertFalse(body.contains("\r\nX-Evil-Header: 1\r\n"))
        // The literal quote must be backslash-escaped so it can't terminate the quoted value early.
        XCTAssertTrue(body.contains(#"filename="evil\".txtX-Evil-Header: 1""#))
    }

    func testNameWithQuoteIsEscapedNotInjected() {
        var form = MultipartFormData()
        form.addField(name: "field\"; evil=\"x", value: "value")
        let body = String(decoding: form.encode(), as: UTF8.self)

        XCTAssertTrue(body.contains(#"name="field\"; evil=\"x""#))
        XCTAssertFalse(body.contains(#"name="field"; evil="x""#))
    }

    func testUploadEncodesAMaliciousFilenameSafelyIntoTheRequestBody() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            )!
            let fixture = """
            {"id": "file_01ABC", "created_at": "2026-01-15T00:00:00Z", "filename": "x", \
            "mime_type": "text/plain", "size_bytes": 2, "type": "file", "downloadable": true, "expires_at": null}
            """.data(using: .utf8)!
            return (response, fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.files.upload(
            file: Data("hi".utf8), filename: "evil\"\r\nX-Evil-Header: 1", contentType: "text/plain"
        )

        let request = try XCTUnwrap(capturedRequest)
        let body = String(decoding: try XCTUnwrap(bodyData(from: request)), as: UTF8.self)
        XCTAssertFalse(body.contains("\r\nX-Evil-Header: 1\r\n"))
    }
}
