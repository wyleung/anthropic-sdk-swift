import XCTest
@testable import Anthropic

final class WebFetchURLSourcesParamTests: XCTestCase {
    private func json<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try HTTPTransport.encoder.encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEveryToolFilterVariantEncodesItsWireShape() throws {
        let tools = [WebFetchURLSourceToolReferenceParam(name: "web_search"), WebFetchURLSourceToolReferenceParam(name: "lookup")]
        let sources = WebFetchURLSourcesParam(
            clientToolResults: .only(tools), serverToolResults: .except([tools[0]]), userInput: .nothing
        )
        let root = try json(sources)

        XCTAssertEqual(root["client_tool_results"] as? NSDictionary, [
            "type": "only", "tools": [["type": "tool_reference", "name": "web_search"], ["type": "tool_reference", "name": "lookup"]],
        ] as NSDictionary)
        XCTAssertEqual(root["server_tool_results"] as? NSDictionary, [
            "type": "except", "tools": [["type": "tool_reference", "name": "web_search"]],
        ] as NSDictionary)
        XCTAssertEqual(root["user_input"] as? NSDictionary, ["type": "none"] as NSDictionary)
    }

    func testAllAndNothingCarryNoToolsKey() throws {
        let root = try json(WebFetchURLSourcesParam(clientToolResults: .all, serverToolResults: .nothing, userInput: .all))
        XCTAssertEqual(root["client_tool_results"] as? NSDictionary, ["type": "all"] as NSDictionary)
        XCTAssertEqual(root["server_tool_results"] as? NSDictionary, ["type": "none"] as NSDictionary)
        XCTAssertEqual(root["user_input"] as? NSDictionary, ["type": "all"] as NSDictionary)
    }

    func testOmittedSourcesAreAbsentSoTheServerDefaultsToEverySource() throws {
        XCTAssertTrue(try json(WebFetchURLSourcesParam()).isEmpty)
        XCTAssertEqual(Set(try json(WebFetchURLSourcesParam(userInput: .all)).keys), ["user_input"])
    }

    func testEveryWebFetchToolVersionAcceptsAndSendsUrlSources() throws {
        let sources = WebFetchURLSourcesParam(userInput: .nothing)
        let expected = ["type": "none"] as NSDictionary
        XCTAssertEqual((try json(WebFetchTool20250910Param(urlSources: sources))["url_sources"] as? [String: Any])?["user_input"] as? NSDictionary, expected)
        XCTAssertEqual((try json(WebFetchTool20260209Param(urlSources: sources))["url_sources"] as? [String: Any])?["user_input"] as? NSDictionary, expected)
        XCTAssertEqual((try json(WebFetchTool20260309Param(urlSources: sources))["url_sources"] as? [String: Any])?["user_input"] as? NSDictionary, expected)
        XCTAssertEqual((try json(WebFetchTool20260318Param(urlSources: sources))["url_sources"] as? [String: Any])?["user_input"] as? NSDictionary, expected)
    }

    func testUrlSourcesIsOmittedFromTheToolWhenNotGiven() throws {
        XCTAssertNil(try json(WebFetchTool20260318Param())["url_sources"])
    }

    func testToolsetsNoLongerSendAllowedCallers() throws {
        // Upstream removed `allowed_callers` from both toolsets; the property is gone, so this is a
        // wire-shape pin that nothing re-adds it.
        XCTAssertNil(try json(ComputerToolset20260801Param())["allowed_callers"])
        XCTAssertNil(try json(BrowserToolset20260801Param())["allowed_callers"])
    }
}
