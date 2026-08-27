import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsMemoryStoreTests: XCTestCase {
    private static let memoryStoreFixture = """
    {
        "id": "memstore_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "description": "User preferences and history",
        "metadata": {"env": "prod"},
        "name": "User Memory",
        "type": "memory_store",
        "updated_at": "2026-01-15T00:00:00Z"
    }
    """.data(using: .utf8)!

    func testDecodesMemoryStore() throws {
        let store = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryStore.self, from: Self.memoryStoreFixture)
        XCTAssertEqual(store.id, "memstore_01ABC")
        XCTAssertNil(store.archivedAt)
        XCTAssertEqual(store.description, "User preferences and history")
        XCTAssertEqual(store.metadata, ["env": "prod"])
        XCTAssertEqual(store.name, "User Memory")
        XCTAssertEqual(store.type, "memory_store")
    }

    func testDecodesDeletedMemoryStore() throws {
        let fixture = """
        {"id": "memstore_01ABC", "type": "memory_store_deleted"}
        """.data(using: .utf8)!
        let deleted = try HTTPTransport.decoder.decode(BetaManagedAgentsDeletedMemoryStore.self, from: fixture)
        XCTAssertEqual(deleted.id, "memstore_01ABC")
        XCTAssertEqual(deleted.type, "memory_store_deleted")
    }

    func testCreateParamsOmitsOptionalFieldsWhenNil() throws {
        let params = BetaMemoryStoreCreateParams(name: "User Memory")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "User Memory")
        XCTAssertNil(json["description"])
        XCTAssertNil(json["metadata"])
    }

    func testUpdateParamsOmitsUnsetFieldsAndEncodesMetadataPatch() throws {
        let params = BetaMemoryStoreUpdateParams(description: "", metadata: ["env": "staging", "owner": nil])
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["description"] as? String, "")
        XCTAssertNil(json["name"])
        let metadata = try XCTUnwrap(json["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["env"] as? String, "staging")
        XCTAssertTrue(metadata["owner"] is NSNull)
    }
}
