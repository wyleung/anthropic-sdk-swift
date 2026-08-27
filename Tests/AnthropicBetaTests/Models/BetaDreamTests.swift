import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaDreamTests: XCTestCase {
    private static let dreamFixture = """
    {
        "id": "dream_01ABC",
        "archived_at": null,
        "created_at": "2026-01-15T00:00:00Z",
        "ended_at": null,
        "error": null,
        "inputs": [
            {"memory_store_id": "memstore_01ABC", "type": "memory_store"},
            {"session_ids": ["session_01ABC", "session_02DEF"], "type": "sessions"}
        ],
        "instructions": "Focus on user preferences",
        "model": {"id": "claude-opus-5", "speed": "fast"},
        "output_behavior": {"type": "create_new"},
        "outputs": [],
        "session_id": null,
        "status": "running",
        "type": "dream",
        "usage": {
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0,
            "input_tokens": 100,
            "output_tokens": 50
        }
    }
    """.data(using: .utf8)!

    func testDecodesDream() throws {
        let dream = try HTTPTransport.decoder.decode(BetaDream.self, from: Self.dreamFixture)
        XCTAssertEqual(dream.id, "dream_01ABC")
        XCTAssertEqual(dream.inputs.count, 2)
        XCTAssertEqual(dream.model.id, "claude-opus-5")
        XCTAssertEqual(dream.model.speed, .fast)
        XCTAssertEqual(dream.status, .running)
        XCTAssertEqual(dream.usage.inputTokens, 100)
        guard case .createNew = dream.outputBehavior else {
            return XCTFail("Expected a createNew output behavior")
        }
    }

    func testDecodesFailedDreamWithError() throws {
        let fixture = """
        {
            "id": "dream_02DEF",
            "archived_at": null,
            "created_at": "2026-01-15T00:00:00Z",
            "ended_at": "2026-01-15T01:00:00Z",
            "error": {"message": "the memory store was archived", "type": "memory_store_archived_error"},
            "inputs": [],
            "instructions": null,
            "model": {"id": "claude-opus-5"},
            "output_behavior": {"memory_store_id": "memstore_01ABC", "type": "update_existing"},
            "outputs": [{"memory_store_id": "memstore_02DEF", "type": "memory_store"}],
            "session_id": null,
            "status": "failed",
            "type": "dream",
            "usage": {
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
                "input_tokens": 10,
                "output_tokens": 5
            }
        }
        """.data(using: .utf8)!
        let dream = try HTTPTransport.decoder.decode(BetaDream.self, from: fixture)
        XCTAssertEqual(dream.status, .failed)
        XCTAssertEqual(dream.error?.message, "the memory store was archived")
        XCTAssertEqual(dream.outputs.first?.memoryStoreId, "memstore_02DEF")
        guard case .updateExisting(let value) = dream.outputBehavior else {
            return XCTFail("Expected an updateExisting output behavior")
        }
        XCTAssertEqual(value.memoryStoreId, "memstore_01ABC")
    }

    // MARK: - BetaDreamStatus (5 variants + unknown)

    func testDreamStatusDecodesAllFiveVariants() throws {
        let statuses: [(String, BetaDreamStatus)] = [
            ("pending", .pending), ("running", .running), ("completed", .completed),
            ("failed", .failed), ("canceled", .canceled),
        ]
        for (wire, expected) in statuses {
            let fixture = "\"\(wire)\"".data(using: .utf8)!
            let decoded = try HTTPTransport.decoder.decode(BetaDreamStatus.self, from: fixture)
            XCTAssertEqual(decoded, expected)
            let encoded = try HTTPTransport.encoder.encode(decoded)
            XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"\(wire)\"")
        }
    }

    func testDreamStatusDecodesUnknownVariant() throws {
        let fixture = "\"dreaming\"".data(using: .utf8)!
        let decoded = try HTTPTransport.decoder.decode(BetaDreamStatus.self, from: fixture)
        guard case .unknown(let value) = decoded else {
            return XCTFail("Expected an unknown status")
        }
        XCTAssertEqual(value, "dreaming")
    }

    // MARK: - BetaDreamInput union

    func testDreamInputDecodesMemoryStoreVariant() throws {
        let fixture = """
        {"memory_store_id": "memstore_01ABC", "type": "memory_store"}
        """.data(using: .utf8)!
        let input = try HTTPTransport.decoder.decode(BetaDreamInput.self, from: fixture)
        guard case .memoryStore(let value) = input else {
            return XCTFail("Expected a memoryStore input")
        }
        XCTAssertEqual(value.memoryStoreId, "memstore_01ABC")
    }

    func testDreamInputDecodesSessionsVariant() throws {
        let fixture = """
        {"session_ids": ["session_01ABC"], "type": "sessions"}
        """.data(using: .utf8)!
        let input = try HTTPTransport.decoder.decode(BetaDreamInput.self, from: fixture)
        guard case .sessions(let value) = input else {
            return XCTFail("Expected a sessions input")
        }
        XCTAssertEqual(value.sessionIds, ["session_01ABC"])
    }

    func testDreamInputDecodesUnknownVariant() throws {
        let fixture = """
        {"type": "future_input"}
        """.data(using: .utf8)!
        let input = try HTTPTransport.decoder.decode(BetaDreamInput.self, from: fixture)
        guard case .unknown(let type, _) = input else {
            return XCTFail("Expected an unknown input")
        }
        XCTAssertEqual(type, "future_input")
    }

    func testDreamInputParamEncodesBothVariants() throws {
        let memoryStore = try HTTPTransport.encoder.encode(BetaDreamInputParam.memoryStore(memoryStoreId: "memstore_01ABC"))
        let memoryStoreJson = try XCTUnwrap(JSONSerialization.jsonObject(with: memoryStore) as? [String: Any])
        XCTAssertEqual(memoryStoreJson["memory_store_id"] as? String, "memstore_01ABC")
        XCTAssertEqual(memoryStoreJson["type"] as? String, "memory_store")

        let sessions = try HTTPTransport.encoder.encode(BetaDreamInputParam.sessions(sessionIds: ["session_01ABC"]))
        let sessionsJson = try XCTUnwrap(JSONSerialization.jsonObject(with: sessions) as? [String: Any])
        XCTAssertEqual(sessionsJson["session_ids"] as? [String], ["session_01ABC"])
        XCTAssertEqual(sessionsJson["type"] as? String, "sessions")
    }

    // MARK: - BetaOutputBehavior union

    func testOutputBehaviorDecodesCreateNewVariant() throws {
        let fixture = """
        {"type": "create_new"}
        """.data(using: .utf8)!
        let behavior = try HTTPTransport.decoder.decode(BetaOutputBehavior.self, from: fixture)
        guard case .createNew = behavior else {
            return XCTFail("Expected a createNew output behavior")
        }
    }

    func testOutputBehaviorDecodesUpdateExistingVariant() throws {
        let fixture = """
        {"memory_store_id": "memstore_01ABC", "type": "update_existing"}
        """.data(using: .utf8)!
        let behavior = try HTTPTransport.decoder.decode(BetaOutputBehavior.self, from: fixture)
        guard case .updateExisting(let value) = behavior else {
            return XCTFail("Expected an updateExisting output behavior")
        }
        XCTAssertEqual(value.memoryStoreId, "memstore_01ABC")
    }

    func testOutputBehaviorDecodesUnknownVariant() throws {
        let fixture = """
        {"type": "future_behavior"}
        """.data(using: .utf8)!
        let behavior = try HTTPTransport.decoder.decode(BetaOutputBehavior.self, from: fixture)
        guard case .unknown(let type, _) = behavior else {
            return XCTFail("Expected an unknown output behavior")
        }
        XCTAssertEqual(type, "future_behavior")
    }

    func testOutputBehaviorParamEncodesBothVariants() throws {
        let createNew = try HTTPTransport.encoder.encode(BetaOutputBehaviorParam.createNew)
        let createNewJson = try XCTUnwrap(JSONSerialization.jsonObject(with: createNew) as? [String: Any])
        XCTAssertEqual(createNewJson["type"] as? String, "create_new")
        XCTAssertNil(createNewJson["memory_store_id"])

        let updateExisting = try HTTPTransport.encoder.encode(BetaOutputBehaviorParam.updateExisting(memoryStoreId: "memstore_01ABC"))
        let updateExistingJson = try XCTUnwrap(JSONSerialization.jsonObject(with: updateExisting) as? [String: Any])
        XCTAssertEqual(updateExistingJson["type"] as? String, "update_existing")
        XCTAssertEqual(updateExistingJson["memory_store_id"] as? String, "memstore_01ABC")
    }

    // MARK: - BetaDreamModelParam bare-string-or-config union

    func testDreamModelParamEncodesBareString() throws {
        let param: BetaDreamModelParam = "claude-opus-5"
        let encoded = try HTTPTransport.encoder.encode(param)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"claude-opus-5\"")
    }

    func testDreamModelParamEncodesConfigObject() throws {
        let param = BetaDreamModelParam.config(BetaDreamModelConfigParams(id: "claude-opus-5", speed: .fast))
        let encoded = try HTTPTransport.encoder.encode(param)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["id"] as? String, "claude-opus-5")
        XCTAssertEqual(json["speed"] as? String, "fast")
    }

    // MARK: - BetaDreamCreateParams

    func testCreateParamsEncodesRequiredAndOptionalFields() throws {
        let params = BetaDreamCreateParams(
            inputs: [.memoryStore(memoryStoreId: "memstore_01ABC")],
            model: "claude-opus-5",
            instructions: "Focus on user preferences",
            outputBehavior: .createNew
        )
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus-5")
        XCTAssertEqual(json["instructions"] as? String, "Focus on user preferences")
        let inputs = try XCTUnwrap(json["inputs"] as? [[String: Any]])
        XCTAssertEqual(inputs.first?["memory_store_id"] as? String, "memstore_01ABC")
        let outputBehavior = try XCTUnwrap(json["output_behavior"] as? [String: Any])
        XCTAssertEqual(outputBehavior["type"] as? String, "create_new")
    }

    func testCreateParamsOmitsOptionalFieldsWhenNil() throws {
        let params = BetaDreamCreateParams(inputs: [.sessions(sessionIds: ["session_01ABC"])], model: "claude-opus-5")
        let encoded = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(json["instructions"])
        XCTAssertNil(json["output_behavior"])
    }
}
