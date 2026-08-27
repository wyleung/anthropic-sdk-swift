import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsAgentWithOverridesParamsTests: XCTestCase {
    private func encode(_ params: BetaManagedAgentsAgentWithOverridesParams) throws -> [String: Any] {
        let data = try HTTPTransport.encoder.encode(params)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testSystemOmittedIsNotPresentInEncodedJSON() throws {
        let json = try encode(BetaManagedAgentsAgentWithOverridesParams(id: "agent_01ABC"))
        XCTAssertNil(json["system"])
    }

    func testSystemExplicitNullIsEncodedAsJSONNull() throws {
        let json = try encode(
            BetaManagedAgentsAgentWithOverridesParams(id: "agent_01ABC", system: .some(nil))
        )
        XCTAssertTrue(json["system"] is NSNull)
    }

    func testSystemExplicitValueIsEncodedAsString() throws {
        let json = try encode(
            BetaManagedAgentsAgentWithOverridesParams(id: "agent_01ABC", system: .some("Custom system prompt"))
        )
        XCTAssertEqual(json["system"] as? String, "Custom system prompt")
    }
}
