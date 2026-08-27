import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaCredentialParamsTests: XCTestCase {
    func testCreateParamsOmitsDisplayNameAndMetadataWhenNil() throws {
        let params = BetaCredentialCreateParams(
            auth: .staticBearer(BetaManagedAgentsStaticBearerCreateParams(token: "secret-token", mcpServerUrl: "https://mcp.example.com"))
        )
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["display_name"])
        XCTAssertNil(json["metadata"])
        let auth = try XCTUnwrap(json["auth"] as? [String: Any])
        XCTAssertEqual(auth["type"] as? String, "static_bearer")
        XCTAssertEqual(auth["token"] as? String, "secret-token")
    }

    func testCreateParamsEncodesDisplayNameAndMetadataWhenSet() throws {
        let params = BetaCredentialCreateParams(
            auth: .environmentVariable(
                BetaManagedAgentsEnvironmentVariableCreateParams(
                    networking: .unrestricted(BetaManagedAgentsUnrestrictedCredentialNetworkingParams()),
                    secretName: "API_KEY",
                    secretValue: "shh"
                )
            ),
            displayName: "My Credential",
            metadata: ["env": "prod"]
        )
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "My Credential")
        XCTAssertEqual(json["metadata"] as? [String: String], ["env": "prod"])
        let auth = try XCTUnwrap(json["auth"] as? [String: Any])
        XCTAssertEqual(auth["type"] as? String, "environment_variable")
        XCTAssertEqual(auth["secret_value"] as? String, "shh")
    }

    func testUpdateParamsOmitsUnsetFieldsAndEncodesMetadataPatch() throws {
        let params = BetaCredentialUpdateParams(metadata: ["env": "staging", "owner": nil])
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["auth"])
        XCTAssertNil(json["display_name"])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["env"] as? String, "staging")
        XCTAssertTrue(metadata["owner"] is NSNull)
    }

    func testUpdateParamsEncodesAuthWhenSet() throws {
        let params = BetaCredentialUpdateParams(
            auth: .staticBearer(BetaManagedAgentsStaticBearerUpdateParams(token: "new-token"))
        )
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let auth = try XCTUnwrap(json["auth"] as? [String: Any])
        XCTAssertEqual(auth["type"] as? String, "static_bearer")
        XCTAssertEqual(auth["token"] as? String, "new-token")
        XCTAssertNil(json["display_name"])
        XCTAssertNil(json["metadata"])
    }
}
