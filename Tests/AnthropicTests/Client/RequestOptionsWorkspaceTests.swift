import XCTest
@testable import Anthropic

final class RequestOptionsWorkspaceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    private func capturedHeaders(options: RequestOptions) async throws -> [String: String] {
        var headers: [String: String] = [:]
        MockURLProtocol.responder = { request in
            headers = request.allHTTPHeaderFields ?? [:]
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(#"{"id": "m", "created_at": "2026-01-01T00:00:00Z", "display_name": "M", "type": "model"}"#.utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.models.retrieve("m", options: options)
        return headers
    }

    func testWorkspaceIdIsSentAsTheAnthropicWorkspaceIdHeader() async throws {
        let headers = try await capturedHeaders(options: RequestOptions(workspaceId: "wrkspc_011CZkZaBF1tNoB5wlCeusgy"))
        XCTAssertEqual(headers["anthropic-workspace-id"], "wrkspc_011CZkZaBF1tNoB5wlCeusgy")
    }

    func testNoWorkspaceHeaderIsSentByDefault() async throws {
        let headers = try await capturedHeaders(options: RequestOptions())
        XCTAssertNil(headers["anthropic-workspace-id"])
    }

    func testWorkspaceIdWinsOverADifferentlyCasedHeaderRatherThanSendingBoth() {
        // `headers` is a plain dictionary, so "Anthropic-Workspace-Id" would otherwise sit beside
        // the lowercase key and be applied in unspecified order.
        let options = RequestOptions(headers: ["Anthropic-Workspace-Id": "wrkspc_old", "x-other": "1"], workspaceId: "wrkspc_new")
        let workspaceKeys = options.headers.keys.filter { $0.lowercased() == "anthropic-workspace-id" }
        XCTAssertEqual(workspaceKeys, ["anthropic-workspace-id"])
        XCTAssertEqual(options.headers["anthropic-workspace-id"] ?? nil, "wrkspc_new")
        XCTAssertEqual(options.headers["x-other"] ?? nil, "1", "unrelated headers are kept")
    }

    func testWorkspaceIdSurvivesRebuildingOptionsFromTheirHeaders() async throws {
        // Callers (and `SessionToolRunner`) rebuild a RequestOptions from `.headers`; since the
        // workspace is folded into the headers, that cannot lose it.
        let original = RequestOptions(workspaceId: "wrkspc_keep")
        let rebuilt = RequestOptions(headers: original.headers, maxRetries: 1)
        let headers = try await capturedHeaders(options: rebuilt)
        XCTAssertEqual(headers["anthropic-workspace-id"], "wrkspc_keep")
    }
}
