import XCTest
@testable import Anthropic

final class FilesTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private static let fileFixture = """
    {
        "id": "file_01ABC",
        "created_at": "2026-01-15T00:00:00Z",
        "filename": "report.pdf",
        "mime_type": "application/pdf",
        "size_bytes": 1024,
        "type": "file",
        "downloadable": true,
        "expires_at": null
    }
    """.data(using: .utf8)!

    private func jsonResponse(_ data: Data) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/")!, statusCode: 200, httpVersion: nil,
            headerFields: ["content-type": "application/json"]
        )!
        return (response, data)
    }

    func testListEncodesIdsAsBracketArrayQueryParams() async throws {
        let fixture = """
        {"data": [\(String(data: Self.fileFixture, encoding: .utf8)!)], "next_page": null}
        """.data(using: .utf8)!

        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/files")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let idValues = query.filter { $0.name == "ids[]" }.map(\.value)
            XCTAssertEqual(idValues, ["file_01ABC", "file_02DEF"])
            return self.jsonResponse(fixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let page = try await client.files.list(ids: ["file_01ABC", "file_02DEF"])

        XCTAssertEqual(page.data.count, 1)
        XCTAssertNil(page.nextPage)
    }

    func testDeleteDecodesDeletedFile() async throws {
        let fixture = """
        {"id": "file_01ABC", "type": "file_deleted"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/files/file_01ABC")
            return self.jsonResponse(fixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.files.delete("file_01ABC")
        XCTAssertEqual(deleted.type, "file_deleted")
    }

    func testDeleteDecodesDeletedFileWithoutType() async throws {
        let fixture = """
        {"id": "file_01ABC"}
        """.data(using: .utf8)!
        MockURLProtocol.responder = { _ in self.jsonResponse(fixture) }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let deleted = try await client.files.delete("file_01ABC")
        XCTAssertNil(deleted.type)
    }

    func testDownloadReturnsRawBytes() async throws {
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/files/file_01ABC/content")
            XCTAssertEqual(request.value(forHTTPHeaderField: "accept"), "application/binary")
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["content-type": "application/binary"]
            )!
            return (response, bytes)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let data = try await client.files.download("file_01ABC")
        XCTAssertEqual(data, bytes)
    }

    func testRetrieveMetadataDecodesFileMetadata() async throws {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.path, "/v1/files/file_01ABC")
            return self.jsonResponse(Self.fileFixture)
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let metadata = try await client.files.retrieveMetadata("file_01ABC")
        XCTAssertEqual(metadata.filename, "report.pdf")
        XCTAssertEqual(metadata.sizeBytes, 1024)
        XCTAssertEqual(metadata.downloadable, true)
    }

    func testUploadSendsMultipartBodyWithFileAndExpiry() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.responder = { request in
            capturedRequest = request
            XCTAssertEqual(request.url?.path, "/v1/files")
            XCTAssertEqual(request.httpMethod, "POST")
            return self.jsonResponse(Self.fileFixture)
        }

        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        let payload = Data("hello world".utf8)
        let metadata = try await client.files.upload(
            file: payload, filename: "hello.txt", contentType: "text/plain", expiresInSeconds: 3600
        )
        XCTAssertEqual(metadata.id, "file_01ABC")

        let request = try XCTUnwrap(capturedRequest)
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "content-type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))

        let body = try XCTUnwrap(bodyData(from: request))
        let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))

        XCTAssertTrue(bodyString.contains("--\(boundary)"))
        XCTAssertTrue(bodyString.contains("name=\"file\"; filename=\"hello.txt\""))
        XCTAssertTrue(bodyString.contains("Content-Type: text/plain"))
        XCTAssertTrue(bodyString.contains("hello world"))
        XCTAssertTrue(bodyString.contains("name=\"expires_in_seconds\""))
        XCTAssertTrue(bodyString.contains("3600"))
        XCTAssertTrue(bodyString.hasSuffix("--\(boundary)--\r\n"))
    }
}
