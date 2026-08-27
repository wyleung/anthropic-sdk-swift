import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaManagedAgentsMemoryTests: XCTestCase {
    private static let memoryBasicFixture = """
    {
        "id": "mem_01ABC",
        "content_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "content_size_bytes": 42,
        "created_at": "2026-01-15T00:00:00Z",
        "memory_store_id": "memstore_01ABC",
        "memory_version_id": "memver_01ABC",
        "path": "/notes/todo",
        "type": "memory",
        "updated_at": "2026-01-15T00:00:00Z",
        "content": null
    }
    """.data(using: .utf8)!

    private static let memoryFullFixture = """
    {
        "id": "mem_01ABC",
        "content_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "content_size_bytes": 42,
        "created_at": "2026-01-15T00:00:00Z",
        "memory_store_id": "memstore_01ABC",
        "memory_version_id": "memver_01ABC",
        "path": "/notes/todo",
        "type": "memory",
        "updated_at": "2026-01-15T00:00:00Z",
        "content": "Buy milk"
    }
    """.data(using: .utf8)!

    func testDecodesMemoryWithNilContentForBasicView() throws {
        let memory = try HTTPTransport.decoder.decode(BetaManagedAgentsMemory.self, from: Self.memoryBasicFixture)
        XCTAssertEqual(memory.id, "mem_01ABC")
        XCTAssertEqual(memory.path, "/notes/todo")
        XCTAssertEqual(memory.memoryStoreId, "memstore_01ABC")
        XCTAssertEqual(memory.memoryVersionId, "memver_01ABC")
        XCTAssertEqual(memory.contentSizeBytes, 42)
        XCTAssertNil(memory.content)
    }

    func testDecodesMemoryWithPopulatedContentForFullView() throws {
        let memory = try HTTPTransport.decoder.decode(BetaManagedAgentsMemory.self, from: Self.memoryFullFixture)
        XCTAssertEqual(memory.content, "Buy milk")
    }

    func testDecodesMemoryListItemMemoryVariant() throws {
        let item = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryListItem.self, from: Self.memoryBasicFixture)
        guard case .memory(let memory) = item else {
            return XCTFail("expected .memory variant")
        }
        XCTAssertEqual(memory.id, "mem_01ABC")
    }

    func testDecodesMemoryListItemMemoryPrefixVariant() throws {
        let fixture = """
        {"path": "/notes/", "type": "memory_prefix"}
        """.data(using: .utf8)!
        let item = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryListItem.self, from: fixture)
        guard case .memoryPrefix(let prefix) = item else {
            return XCTFail("expected .memoryPrefix variant")
        }
        XCTAssertEqual(prefix.path, "/notes/")
    }

    func testDecodesMemoryListItemUnknownVariant() throws {
        let fixture = """
        {"path": "/notes/todo", "type": "memory_symlink"}
        """.data(using: .utf8)!
        let item = try HTTPTransport.decoder.decode(BetaManagedAgentsMemoryListItem.self, from: fixture)
        guard case .unknown(let type, _) = item else {
            return XCTFail("expected .unknown variant")
        }
        XCTAssertEqual(type, "memory_symlink")
    }

    func testDecodesDeletedMemory() throws {
        let fixture = """
        {"id": "mem_01ABC", "type": "memory_deleted"}
        """.data(using: .utf8)!
        let deleted = try HTTPTransport.decoder.decode(BetaManagedAgentsDeletedMemory.self, from: fixture)
        XCTAssertEqual(deleted.id, "mem_01ABC")
        XCTAssertEqual(deleted.type, "memory_deleted")
    }

    func testEncodesPreconditionParam() throws {
        let precondition = BetaManagedAgentsPreconditionParam(contentSha256: "abc123")
        let encoded = try HTTPTransport.encoder.encode(precondition)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "content_sha256")
        XCTAssertEqual(json["content_sha256"] as? String, "abc123")
    }

    func testCreateParamsEncodesEmptyStringContentLiterally() throws {
        let params = BetaMemoryCreateParams(content: "", path: "/notes/empty")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["content"] as? String, "")
        XCTAssertEqual(json["path"] as? String, "/notes/empty")
    }

    func testUpdateParamsOmitsUnsetFields() throws {
        let params = BetaMemoryUpdateParams(path: "/notes/renamed")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["path"] as? String, "/notes/renamed")
        XCTAssertNil(json["content"])
        XCTAssertNil(json["precondition"])
    }
}
