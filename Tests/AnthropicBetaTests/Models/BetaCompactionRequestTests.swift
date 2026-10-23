import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// A compaction request returns only the compaction block, never a reply, so the API rejects the
/// params that only shape a reply. `forCompactionRequest` rebuilds the params field by field; these
/// tests make sure it strips exactly those and silently drops nothing else.
final class BetaCompactionRequestTests: XCTestCase {
    private let schema = JSONOutputFormatParam(schema: .object(["type": .string("object")]))

    /// Every optional field populated, so a field the rebuild forgets to thread through shows up as nil.
    private func fullParams(toolChoice: ToolChoiceParam = .any(ToolChoiceAnyParam())) -> BetaMessageCreateParams {
        BetaMessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 99, messages: [.user("Hi")],
            cacheControl: CacheControlEphemeral(ttl: .oneHour),
            compaction: nil,
            container: .id("c_1"),
            contextManagement: .object(["edits": .array([.object(["type": .string("clear_tool_uses_20250919")])])]),
            diagnostics: DiagnosticsParam(previousMessageId: "msg_prev"),
            fallbackCreditToken: "tok",
            fallbacks: .array([
                .object([
                    "model": .string("claude-sonnet-5-5"),
                    "output_config": .object(["effort": .string("low"), "format": .object(["type": .string("json_schema")])]),
                ]),
                .object(["model": .string("claude-haiku-5-5")]),
            ]),
            inferenceGeo: "us",
            mcpServers: [BetaRequestMCPServerURLDefinitionParam(name: "docs", url: "https://m.example")],
            metadata: MetadataParam(userId: "u"),
            outputConfig: BetaOutputConfigParam(effort: .high, format: schema, taskBudget: .object(["total": .number(5)])),
            serviceTier: .standardOnly,
            speed: .fast,
            stopSequences: ["STOP"],
            system: .text("sys"),
            thinking: .enabled(BetaThinkingConfigEnabledParam(budgetTokens: 2048)),
            toolChoice: toolChoice,
            tools: [.tool(.custom(ToolParam(name: "t", inputSchema: .object([:]))))]
        )
    }

    func testStripsOnlyWhatShapesAReplyAndKeepsEverythingElse() throws {
        let full = fullParams()
        let request = full.forCompactionRequest(BetaCompactionConfigParam(instructions: "Be brief."))

        // Added.
        XCTAssertEqual(request.compaction, BetaCompactionConfigParam(instructions: "Be brief."))
        // Stripped.
        XCTAssertNil(request.contextManagement)
        XCTAssertNil(request.stopSequences)
        XCTAssertNil(request.toolChoice, "a forcing tool_choice can't apply to a request that makes no reply")
        XCTAssertNil(request.outputConfig?.format)
        // Everything else survives; the full fixture leaves no other field unset, so a dropped one is nil.
        for child in Mirror(reflecting: request).children {
            let label = child.label ?? "?"
            if ["contextManagement", "stopSequences", "toolChoice"].contains(label) { continue }
            XCTAssertFalse(String(describing: child.value) == "nil", "\(label) was dropped from the compaction request")
        }
        XCTAssertEqual(request.outputConfig?.effort, .high)
        XCTAssertEqual(request.outputConfig?.taskBudget, full.outputConfig?.taskBudget)
        XCTAssertEqual(request.messages, full.messages)
        XCTAssertEqual(request.tools, full.tools)
        XCTAssertEqual(request.thinking, full.thinking)
    }

    func testFormatIsAlsoStrippedFromEachFallbacksOutputConfig() throws {
        let request = fullParams().forCompactionRequest(BetaCompactionConfigParam())

        guard case .array(let fallbacks)? = request.fallbacks else { return XCTFail("fallbacks dropped") }
        XCTAssertEqual(fallbacks.count, 2)
        XCTAssertEqual(fallbacks[0]["model"]?.stringValue, "claude-sonnet-5-5")
        XCTAssertEqual(fallbacks[0]["output_config"]?["effort"]?.stringValue, "low", "only `format` goes")
        XCTAssertNil(fallbacks[0]["output_config"]?["format"])
        XCTAssertEqual(fallbacks[1], .object(["model": .string("claude-haiku-5-5")]), "no output_config, left alone")
    }

    func testAToolChoiceThatDoesNotForceAToolIsKept() throws {
        for choice in [ToolChoiceParam.auto(ToolChoiceAutoParam()), .none(ToolChoiceNoneParam())] {
            XCTAssertEqual(fullParams(toolChoice: choice).forCompactionRequest(BetaCompactionConfigParam()).toolChoice, choice)
        }
        let named = fullParams(toolChoice: .tool(ToolChoiceToolParam(name: "t")))
        XCTAssertNil(named.forCompactionRequest(BetaCompactionConfigParam()).toolChoice)
    }

    func testRequestOmitsTheStrippedKeysOnTheWire() throws {
        let data = try HTTPTransport.encoder.encode(fullParams().forCompactionRequest(BetaCompactionConfigParam()))
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual((wire["compaction"] as? [String: Any])?["type"] as? String, "summarize")
        for key in ["context_management", "stop_sequences", "tool_choice"] {
            XCTAssertNil(wire[key], "\(key) must not be sent with a compaction request")
        }
        XCTAssertEqual((wire["output_config"] as? [String: Any])?["effort"] as? String, "high")
        XCTAssertNil((wire["output_config"] as? [String: Any])?["format"])
    }

    func testRecognizesACompactionEditInContextManagement() {
        func params(_ edits: [JSONValue]?) -> BetaMessageCreateParams {
            BetaMessageCreateParams(
                model: "m", maxTokens: 1, messages: [.user("Hi")],
                contextManagement: edits.map { .object(["edits": .array($0)]) }
            )
        }
        XCTAssertFalse(params(nil).hasCompactionEdit)
        XCTAssertFalse(params([]).hasCompactionEdit)
        XCTAssertFalse(params([.object(["type": .string("clear_tool_uses_20250919")])]).hasCompactionEdit)
        XCTAssertTrue(params([.object(["type": .string("compact_20260904")])]).hasCompactionEdit)
        XCTAssertTrue(
            params([.object(["type": .string("clear_thinking_20251015")]), .object(["type": .string("compact_20260904")])])
                .hasCompactionEdit
        )
    }
}
