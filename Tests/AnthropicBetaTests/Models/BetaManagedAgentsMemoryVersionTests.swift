import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsMemoryVersionTests: XCTestCase {
    private static let versionFixture = """
    {
        "id": "memver_01ABC",
        "created_at": "2026-01-15T00:00:00Z",
        "memory_id": "mem_01ABC",
        "memory_store_id": "memstore_01ABC",
        "operation": "modified",
        "type": "memory_version",
        "content": "Buy milk",
        "content_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "content_size_bytes": 8,
        "created_by": {"type": "session_actor", "session_id": "sesn_01ABC"},
        "path": "/notes/todo",
        "redacted_at": null,
        "redacted_by": null
    }
    """.data(using: .utf8)!

    func testDecodesMemoryVersion() throws {
        let version = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryVersion.self, from: Self.versionFixture)
        XCTAssertEqual(version.id, "memver_01ABC")
        XCTAssertEqual(version.memoryId, "mem_01ABC")
        XCTAssertEqual(version.memoryStoreId, "memstore_01ABC")
        XCTAssertEqual(version.operation, .modified)
        XCTAssertEqual(version.content, "Buy milk")
        XCTAssertNil(version.redactedAt)
        guard case .session(let actor)? = version.createdBy else {
            return XCTFail("expected .session createdBy actor")
        }
        XCTAssertEqual(actor.sessionId, "sesn_01ABC")
    }

    func testDecodesRedactedVersionWithAllContentFieldsNil() throws {
        let fixture = """
        {
            "id": "memver_01DEF",
            "created_at": "2026-01-15T00:00:00Z",
            "memory_id": "mem_01ABC",
            "memory_store_id": "memstore_01ABC",
            "operation": "modified",
            "type": "memory_version",
            "content": null,
            "content_sha256": null,
            "content_size_bytes": null,
            "created_by": null,
            "path": null,
            "redacted_at": "2026-02-01T00:00:00Z",
            "redacted_by": {"type": "user_actor", "user_id": "user_01ABC"}
        }
        """.data(using: .utf8)!
        let version = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryVersion.self, from: fixture)
        XCTAssertNil(version.content)
        XCTAssertNil(version.contentSha256)
        XCTAssertNil(version.contentSizeBytes)
        XCTAssertNil(version.path)
        XCTAssertEqual(version.redactedAt, "2026-02-01T00:00:00Z")
        guard case .user(let actor)? = version.redactedBy else {
            return XCTFail("expected .user redactedBy actor")
        }
        XCTAssertEqual(actor.userId, "user_01ABC")
    }

    func testDecodesOperationUnknownFallback() throws {
        let decoded = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryVersionOperation.self, from: "\"merged\"".data(using: .utf8)!)
        XCTAssertEqual(decoded, .unknown("merged"))
    }

    func testActorDecodesApiActorVariant() throws {
        let fixture = """
        {"type": "api_actor", "api_key_id": "apikey_01ABC"}
        """.data(using: .utf8)!
        let actor = try HTTPTransport.decoder.decode(BetaManagedAgentsActor.self, from: fixture)
        guard case .api(let value) = actor else {
            return XCTFail("expected .api variant")
        }
        XCTAssertEqual(value.apiKeyId, "apikey_01ABC")
    }

    func testActorDecodesServiceAccountVariant() throws {
        let fixture = """
        {"type": "service_account_actor", "service_account_id": "svac_01ABC"}
        """.data(using: .utf8)!
        let actor = try HTTPTransport.decoder.decode(BetaManagedAgentsActor.self, from: fixture)
        guard case .serviceAccount(let value) = actor else {
            return XCTFail("expected .serviceAccount variant")
        }
        XCTAssertEqual(value.serviceAccountId, "svac_01ABC")
    }

    func testActorDecodesUnknownFallback() throws {
        let fixture = """
        {"type": "webhook_actor", "webhook_id": "whk_01ABC"}
        """.data(using: .utf8)!
        let actor = try HTTPTransport.decoder.decode(BetaManagedAgentsActor.self, from: fixture)
        guard case .unknown(let type, _) = actor else {
            return XCTFail("expected .unknown variant")
        }
        XCTAssertEqual(type, "webhook_actor")
    }
}
