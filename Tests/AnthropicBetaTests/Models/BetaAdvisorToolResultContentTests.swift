import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Regression coverage for Fix #11: an unrecognized `type` discriminator must decode into
/// `.unknown` (forward-compatible) instead of throwing, matching the established convention used
/// elsewhere (e.g. `BetaMessageBatchResult`).
final class BetaAdvisorToolResultContentTests: XCTestCase {
    func testUnrecognizedTypeDecodesToUnknownInsteadOfThrowing() throws {
        let json = #"{"type": "advisor_tool_result_something_new", "foo": "bar"}"#.data(using: .utf8)!
        let content = try JSONDecoder().decode(BetaAdvisorToolResultContent.self, from: json)

        guard case .unknown(let type, let raw) = content else {
            return XCTFail("Expected .unknown, got \(content)")
        }
        XCTAssertEqual(type, "advisor_tool_result_something_new")
        XCTAssertEqual(raw["foo"]?.stringValue, "bar")
    }

    func testUnknownRoundTripsThroughEncoding() throws {
        let json = #"{"type": "advisor_tool_result_something_new", "foo": "bar"}"#.data(using: .utf8)!
        let content = try JSONDecoder().decode(BetaAdvisorToolResultContent.self, from: json)

        let reencoded = try JSONEncoder().encode(content)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "advisor_tool_result_something_new")
        XCTAssertEqual(object["foo"] as? String, "bar")
    }
}
