import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Beta model info: lifecycle/line/schedule fields, the compaction and server-tool capabilities, and the
/// `lifecycle` list filter.
final class BetaModelInfoLifecycleTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    func testBetaModelInfoDecodesLifecycleAndCompactionCapability() throws {
        let model = try HTTPTransport.decoder.decode(BetaModelInfo.self, from: Data("""
        {
            "id": "claude-opus-5-5", "created_at": "2026-09-22T00:00:00Z", "display_name": "Claude Opus 5.5", "type": "model",
            "lifecycle": "active", "line": "opus", "deprecated_at": null, "retires_at": null,
            "capabilities": {
                "batch": {"supported": true}, "citations": {"supported": true}, "code_execution": {"supported": true},
                "compaction": {"supported": true, "summarize": {"supported": true}},
                "context_management": {"supported": true},
                "effort": {"supported": true, "low": {"supported": true}, "medium": {"supported": true},
                           "high": {"supported": true}, "max": {"supported": true}},
                "image_input": {"supported": true}, "pdf_input": {"supported": true},
                "server_tools": {"supported": true, "code_execution": {"supported": true}, "web_search": {"supported": true}},
                "structured_outputs": {"supported": true},
                "thinking": {"supported": true, "types": {"adaptive": {"supported": true}, "between_tools": {"supported": true},
                                                           "disabled": {"supported": true}, "enabled": {"supported": false}}}
            }
        }
        """.utf8))
        XCTAssertEqual(model.lifecycle, .active)
        XCTAssertEqual(model.line, .opus)
        XCTAssertEqual(model.capabilities?.compaction?.summarize.supported, true)
        XCTAssertEqual(model.capabilities?.serverTools?.webSearch.supported, true)
        XCTAssertEqual(model.capabilities?.thinking.types.betweenTools?.supported, true)
    }

    func testBetaModelInfoWithoutTheNewFieldsStillDecodes() throws {
        let model = try HTTPTransport.decoder.decode(BetaModelInfo.self, from: Data("""
        {"id": "m", "created_at": "2026-01-01T00:00:00Z", "display_name": "M", "type": "model"}
        """.utf8))
        XCTAssertNil(model.lifecycle)
        XCTAssertNil(model.capabilities)
    }

    func testListSendsLifecycleAsRepeatedBracketedQueryItemsAlongsideTheBetaFlag() async throws {
        var seenQuery: String?
        MockURLProtocol.responder = { request in
            seenQuery = request.url?.query
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["content-type": "application/json"]
            )!
            return (response, Data(#"{"data": [], "has_more": false}"#.utf8))
        }
        let client = AnthropicClient(apiKey: "test-key", urlSession: MockURLProtocol.makeSession())
        _ = try await client.beta.models.list(lifecycle: ["retired", "deprecated"], limit: 3)

        let items = try XCTUnwrap(seenQuery).split(separator: "&").map { String($0).removingPercentEncoding ?? String($0) }
        XCTAssertTrue(items.contains("beta=true"), "\(items)")
        XCTAssertTrue(items.contains("lifecycle[]=retired"), "\(items)")
        XCTAssertTrue(items.contains("lifecycle[]=deprecated"), "\(items)")
        XCTAssertTrue(items.contains("limit=3"), "\(items)")
    }
}
