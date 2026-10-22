import XCTest
@testable import Anthropic

/// Upstream 2026-10 additions to the GA Messages surface: `diagnostics` (cache-miss reasons),
/// `speed`, and the `between_tools` thinking config.
final class MessagesDiagnosticsAndSpeedTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    // MARK: - decoding

    private func decodeMessage(extraFields: String = "", usageExtra: String = "") throws -> Message {
        let json = """
        {
            "id": "msg_1", "type": "message", "role": "assistant", "model": "claude-opus-5-5",
            "content": [{"type": "text", "text": "Hi"}],
            "stop_reason": "end_turn", "stop_sequence": null,
            "usage": {"input_tokens": 3, "output_tokens": 4\(usageExtra)}\(extraFields)
        }
        """
        return try HTTPTransport.decoder.decode(Message.self, from: Data(json.utf8))
    }

    func testMessageWithoutDiagnosticsOrSpeedStillDecodes() throws {
        let message = try decodeMessage()
        XCTAssertNil(message.diagnostics)
        XCTAssertNil(message.usage.speed)
    }

    func testUsageSpeedDecodesAndAnUnknownSpeedDoesNotFailTheMessage() throws {
        XCTAssertEqual(try decodeMessage(usageExtra: #", "speed": "fast""#).usage.speed, .fast)
        XCTAssertEqual(try decodeMessage(usageExtra: #", "speed": "standard""#).usage.speed, .standard)
        XCTAssertEqual(try decodeMessage(usageExtra: #", "speed": "warp""#).usage.speed, .unknown("warp"))
    }

    func testEveryCacheMissReasonDecodesWithItsPayload() throws {
        let cases: [(wire: String, check: (CacheMissReason) -> Bool)] = [
            (#"{"type": "model_changed", "cache_missed_input_tokens": 11}"#,
             { if case .modelChanged(let r) = $0 { return r.cacheMissedInputTokens == 11 } else { return false } }),
            (#"{"type": "system_changed", "cache_missed_input_tokens": 22}"#,
             { if case .systemChanged(let r) = $0 { return r.cacheMissedInputTokens == 22 } else { return false } }),
            (#"{"type": "tools_changed", "cache_missed_input_tokens": 33}"#,
             { if case .toolsChanged(let r) = $0 { return r.cacheMissedInputTokens == 33 } else { return false } }),
            (#"{"type": "messages_changed", "cache_missed_input_tokens": 44}"#,
             { if case .messagesChanged(let r) = $0 { return r.cacheMissedInputTokens == 44 } else { return false } }),
            (#"{"type": "previous_message_not_found"}"#,
             { if case .previousMessageNotFound = $0 { return true } else { return false } }),
            (#"{"type": "unavailable"}"#,
             { if case .unavailable = $0 { return true } else { return false } }),
        ]
        for (wire, check) in cases {
            let message = try decodeMessage(extraFields: #", "diagnostics": {"cache_miss_reason": \#(wire)}"#)
            let reason = try XCTUnwrap(message.diagnostics?.cacheMissReason, wire)
            XCTAssertTrue(check(reason), "wrong case for \(wire): \(reason)")
        }
    }

    func testUnrecognizedCacheMissReasonDegradesToUnknownKeepingItsPayload() throws {
        let message = try decodeMessage(
            extraFields: #", "diagnostics": {"cache_miss_reason": {"type": "thinking_changed", "cache_missed_input_tokens": 7}}"#
        )
        guard case .unknown(let type, let raw) = message.diagnostics?.cacheMissReason else {
            return XCTFail("expected .unknown, got \(String(describing: message.diagnostics))")
        }
        XCTAssertEqual(type, "thinking_changed")
        XCTAssertEqual(raw["cache_missed_input_tokens"], .number(7))
    }

    func testNullCacheMissReasonMeansDiagnosisIsStillPending() throws {
        let message = try decodeMessage(extraFields: #", "diagnostics": {"cache_miss_reason": null}"#)
        XCTAssertNotNil(message.diagnostics, "diagnostics object itself is present")
        XCTAssertNil(message.diagnostics?.cacheMissReason)
    }

    // MARK: - streaming: diagnostics/speed must survive every snapshot reconstruction

    func testDiagnosticsAndSpeedSurviveEveryAccumulatorReconstruction() throws {
        func decode(_ json: String) throws -> RawMessageStreamEvent {
            try HTTPTransport.decoder.decode(RawMessageStreamEvent.self, from: Data(json.utf8))
        }
        var accumulator = MessageAccumulator()
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant",
        "model":"claude-opus-5-5","content":[],
        "diagnostics":{"cache_miss_reason":{"type":"model_changed","cache_missed_input_tokens":9}},
        "usage":{"input_tokens":10,"output_tokens":0,"speed":"fast"}}}
        """#))
        // Each of these rebuilds the whole `Message` from its fields: content_block_start,
        // content_block_delta, message_delta -- a missed field in any one silently drops it.
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
        """#))
        _ = try accumulator.accumulate(try decode(#"""
        {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
        """#))
        let final = try accumulator.accumulate(try decode(#"""
        {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}
        """#))

        XCTAssertEqual(final.usage.speed, .fast)
        guard case .modelChanged(let reason) = final.diagnostics?.cacheMissReason else {
            return XCTFail("diagnostics lost while streaming: \(String(describing: final.diagnostics))")
        }
        XCTAssertEqual(reason.cacheMissedInputTokens, 9)
    }

    // MARK: - encoding

    private func encodedJSON(_ params: MessageCreateParams) throws -> [String: Any] {
        let data = try HTTPTransport.encoder.encode(params)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testSpeedAndDiagnosticsAreSentInTheRequestBody() throws {
        let json = try encodedJSON(MessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 16, messages: [.user("Hi")],
            diagnostics: DiagnosticsParam(previousMessageId: "msg_prev"), speed: .fast
        ))
        XCTAssertEqual(json["speed"] as? String, "fast")
        XCTAssertEqual((json["diagnostics"] as? [String: Any])?["previous_message_id"] as? String, "msg_prev")
    }

    func testFirstTurnDiagnosticsSendsAnExplicitNullInsteadOfOmittingTheKey() throws {
        // Upstream: "Pass `null` on the first turn to opt in without a prior message." Omitting the
        // key would silently opt out, so unlike every other optional this one must encode as null.
        let json = try encodedJSON(MessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 16, messages: [.user("Hi")], diagnostics: DiagnosticsParam()
        ))
        let diagnostics = try XCTUnwrap(json["diagnostics"] as? [String: Any], "diagnostics key must be present")
        XCTAssertTrue(diagnostics.keys.contains("previous_message_id"), "previous_message_id key must be present")
        XCTAssertTrue(diagnostics["previous_message_id"] is NSNull, "...and must be JSON null")
    }

    func testOmittedDiagnosticsAndSpeedAreAbsentFromTheBody() throws {
        let json = try encodedJSON(MessageCreateParams(model: "claude-opus-5-5", maxTokens: 16, messages: [.user("Hi")]))
        XCTAssertNil(json["diagnostics"])
        XCTAssertNil(json["speed"])
    }

    func testBetweenToolsThinkingEncodes() throws {
        let json = try encodedJSON(MessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 16, messages: [.user("Hi")], thinking: .betweenTools(ThinkingConfigBetweenToolsParam())
        ))
        XCTAssertEqual((json["thinking"] as? [String: Any])?["type"] as? String, "between_tools")
    }

    // MARK: - ToolRunner's `with(...)` must not drop fields

    func testWithPreservesEveryFieldSoToolRunnerTurnsDontSilentlyLoseThem() throws {
        let full = MessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 99, messages: [.user("Hi")],
            cacheControl: CacheControlEphemeral(ttl: .oneHour),
            container: .id("container_1"),
            diagnostics: DiagnosticsParam(previousMessageId: "msg_prev"),
            inferenceGeo: "us",
            metadata: MetadataParam(userId: "u1"),
            outputConfig: OutputConfigParam(effort: nil, format: nil),
            serviceTier: .standardOnly,
            speed: .fast,
            stopSequences: ["STOP"],
            system: .text("be brief"),
            thinking: .betweenTools(ThinkingConfigBetweenToolsParam()),
            toolChoice: .auto(ToolChoiceAutoParam()),
            tools: [.custom(ToolParam(name: "t", inputSchema: .object([:])))]
        )
        // Guard the guard: if a field is added to `MessageCreateParams` but not to this fixture, it
        // is nil here and `with` could drop it without the equality below noticing.
        for child in Mirror(reflecting: full).children {
            XCTAssertFalse(
                String(describing: child.value) == "nil", "fixture leaves `\(child.label ?? "?")` unset; populate it"
            )
        }

        let rebuilt = full.with(messages: [.user("Hi")], tools: nil)
        XCTAssertEqual(rebuilt, full)
        XCTAssertEqual(full.with(messages: [.user("next turn")]).speed, .fast)
        XCTAssertEqual(full.with(messages: [.user("next turn")]).diagnostics, DiagnosticsParam(previousMessageId: "msg_prev"))
    }
}
