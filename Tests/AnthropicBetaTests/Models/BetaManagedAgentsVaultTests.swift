import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsVaultTests: XCTestCase {
    private static let vaultFixture = """
    {
        "id": "vault_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "display_name": "Production Vault",
        "metadata": {"env": "prod"},
        "type": "vault",
        "updated_at": "2026-01-15T00:00:00Z"
    }
    """.data(using: .utf8)!

    func testDecodesVault() throws {
        let vault = try HTTPTransport.decoder.decode(BetaManagedAgentsVault.self, from: Self.vaultFixture)
        XCTAssertEqual(vault.id, "vault_01ABC")
        XCTAssertNil(vault.archivedAt)
        XCTAssertEqual(vault.displayName, "Production Vault")
        XCTAssertEqual(vault.metadata, ["env": "prod"])
        XCTAssertEqual(vault.type, "vault")
    }

    func testDecodesDeletedVault() throws {
        let fixture = """
        {"id": "vault_01ABC", "type": "vault_deleted"}
        """.data(using: .utf8)!
        let deleted = try HTTPTransport.decoder.decode(BetaManagedAgentsDeletedVault.self, from: fixture)
        XCTAssertEqual(deleted.id, "vault_01ABC")
        XCTAssertEqual(deleted.type, "vault_deleted")
    }

    func testCreateParamsOmitsMetadataWhenNil() throws {
        let params = BetaVaultCreateParams(displayName: "My Vault")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["display_name"] as? String, "My Vault")
        XCTAssertNil(json["metadata"])
    }

    func testUpdateParamsOmitsUnsetFieldsAndEncodesMetadataPatch() throws {
        let params = BetaVaultUpdateParams(metadata: ["env": "staging", "owner": nil])
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["display_name"])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["env"] as? String, "staging")
        XCTAssertTrue(metadata["owner"] is NSNull)
    }
}
