import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// Upstream 2026-09/10 additions to the Beta Messages surface: signed compaction blocks with tool
/// changes, input transformations, typed cache diagnostics, MCP tool listings and pinned toolsets,
/// Beta-specific thinking config, and the `compaction` request parameter.
final class BetaMessageAdditionsTests: XCTestCase {
    private func decodeMessage(content: String = "[]", extra: String = "") throws -> BetaMessage {
        let json = """
        {
            "id": "msg_1", "type": "message", "role": "assistant", "model": "claude-opus-5-5",
            "content": \(content), "stop_reason": "end_turn", "stop_sequence": null,
            "usage": {"input_tokens": 3, "output_tokens": 4}\(extra)
        }
        """
        return try HTTPTransport.decoder.decode(BetaMessage.self, from: Data(json.utf8))
    }

    private func json<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: HTTPTransport.encoder.encode(value))
    }

    // MARK: - input_transformations

    func testInputTransformationsDecodeBothKindsAndTheirReasons() throws {
        let message = try decodeMessage(extra: """
        , "input_transformations": [
            {"type": "thinking_dropped", "path": "messages[1].content[0]", "reason": "model_binding_mismatch"},
            {"type": "thinking_mismatch_allowed", "path": "messages[3].content[0]", "reason": "end_user_binding_mismatch"}
        ]
        """)
        let entries = try XCTUnwrap(message.inputTransformations)
        guard case .thinkingDropped(let dropped) = entries[0], case .thinkingMismatchAllowed(let allowed) = entries[1] else {
            return XCTFail("wrong cases: \(entries)")
        }
        XCTAssertEqual(dropped.path, "messages[1].content[0]")
        XCTAssertEqual(dropped.reason, .modelBindingMismatch)
        XCTAssertEqual(allowed.reason, .endUserBindingMismatch)
    }

    func testUnrecognizedTransformationTypesAndReasonsDegradeInsteadOfFailing() throws {
        let message = try decodeMessage(extra: """
        , "input_transformations": [
            {"type": "image_downscaled", "path": "messages[0].content[1]"},
            {"type": "thinking_dropped", "path": "p", "reason": "something_new"}
        ]
        """)
        let entries = try XCTUnwrap(message.inputTransformations)
        guard case .unknown(let type, _) = entries[0] else { return XCTFail("expected .unknown") }
        XCTAssertEqual(type, "image_downscaled")
        guard case .thinkingDropped(let dropped) = entries[1] else { return XCTFail("expected thinkingDropped") }
        XCTAssertEqual(dropped.reason, .unknown("something_new"))
    }

    func testEmptyInputTransformationsIsDistinctFromAbsent() throws {
        XCTAssertEqual(try decodeMessage(extra: #", "input_transformations": []"#).inputTransformations, [])
        XCTAssertNil(try decodeMessage().inputTransformations)
    }

    // MARK: - typed diagnostics

    func testBetaMessageDiagnosticsAreNowTyped() throws {
        let message = try decodeMessage(
            extra: #", "diagnostics": {"cache_miss_reason": {"type": "tools_changed", "cache_missed_input_tokens": 42}}"#
        )
        guard case .toolsChanged(let reason) = message.diagnostics?.cacheMissReason else {
            return XCTFail("expected typed .toolsChanged, got \(String(describing: message.diagnostics))")
        }
        XCTAssertEqual(reason.cacheMissedInputTokens, 42)
    }

    // MARK: - compaction block: signature + tool_changes must round-trip

    private let compactionWire = """
    [{
        "type": "compaction", "content": "summary", "encrypted_content": "enc",
        "signature": "sig-123",
        "tool_changes": [
            {"type": "tool_removal", "tool": {"type": "tool_reference", "name": "old_tool"}},
            {"type": "tool_addition", "tool": {"type": "tool_definition",
                "definition": {"name": "new_tool", "description": "d", "input_schema": {"type": "object", "properties": {"userID": {"type": "string"}}}}}},
            {"type": "tool_addition", "tool": {"type": "mcp_toolset_reference", "server_name": "docs"}},
            {"type": "tool_banana", "anything": [1, 2]}
        ]
    }]
    """

    func testCompactionBlockDecodesSignatureAndAllToolChangeShapes() throws {
        let message = try decodeMessage(content: compactionWire)
        guard case .compaction(let block) = message.content.first else { return XCTFail("expected compaction") }
        XCTAssertEqual(block.signature, "sig-123")
        let changes = try XCTUnwrap(block.toolChanges)
        XCTAssertEqual(changes.count, 4)
        guard case .removal(let removal) = changes[0], case .tool(let ref) = removal.tool else { return XCTFail("removal") }
        XCTAssertEqual(ref.name, "old_tool")
        guard case .addition(let addition) = changes[1], case .definition(let definition) = addition.tool else {
            return XCTFail("definition addition")
        }
        XCTAssertEqual(definition.definition["name"]?.stringValue, "new_tool")
        XCTAssertEqual(definition.definition["input_schema"]?["properties"]?["userID"]?["type"]?.stringValue, "string",
                       "a camelCase schema property name must survive decoding untouched")
        guard case .addition(let toolsetAddition) = changes[2], case .mcpToolset(let toolset) = toolsetAddition.tool else {
            return XCTFail("toolset addition")
        }
        XCTAssertEqual(toolset.serverName, "docs")
        guard case .unknown(let type, _) = changes[3] else { return XCTFail("unknown change") }
        XCTAssertEqual(type, "tool_banana")
    }

    func testResponseCompactionBlockConvertsToAParamThatEchoesSignatureAndToolChangesVerbatim() throws {
        let message = try decodeMessage(content: compactionWire)
        let param = try XCTUnwrap(message.content.first).asRequestParam()
        let sent = try XCTUnwrap(try json(param) as? [String: Any])

        XCTAssertEqual(sent["signature"] as? String, "sig-123", "signature must be echoed or the API rejects the block")
        XCTAssertEqual(sent["encrypted_content"] as? String, "enc")
        let echoed = try XCTUnwrap(sent["tool_changes"] as? [[String: Any]])
        XCTAssertEqual(echoed.count, 4)
        XCTAssertEqual(echoed[0]["type"] as? String, "tool_removal")
        let definition = ((echoed[1]["tool"] as? [String: Any])?["definition"] as? [String: Any])
        XCTAssertEqual(definition?["name"] as? String, "new_tool")
        XCTAssertNotNil(
            ((definition?["input_schema"] as? [String: Any])?["properties"] as? [String: Any])?["userID"],
            "camelCase property names inside a pinned definition must not be snake_cased on the way back"
        )
        XCTAssertEqual(echoed[2]["tool"] as? NSDictionary, ["type": "mcp_toolset_reference", "server_name": "docs"] as NSDictionary)
        XCTAssertEqual(echoed[3]["type"] as? String, "tool_banana", "an unrecognized change survives the round trip")
        XCTAssertEqual(echoed[3]["anything"] as? [Int], [1, 2])
    }

    func testEmptyToolChangesStaysEmptyAndAbsentStaysAbsentThroughTheRoundTrip() throws {
        func echoed(_ wire: String) throws -> [String: Any] {
            let block = try XCTUnwrap(try decodeMessage(content: wire).content.first)
            return try XCTUnwrap(try json(block.asRequestParam()) as? [String: Any])
        }
        // `[]` means "computed: no tool changed"; absent means "not computed". The server treats them differently.
        let empty = try echoed(#"[{"type": "compaction", "content": "s", "signature": "x", "tool_changes": []}]"#)
        XCTAssertEqual((empty["tool_changes"] as? [Any])?.count, 0)
        let absent = try echoed(#"[{"type": "compaction", "content": "s", "signature": "x"}]"#)
        XCTAssertNil(absent["tool_changes"])
    }

    func testCompactionWithNoSignatureOrChangesStillRoundTripsAsBefore() throws {
        let block = try XCTUnwrap(try decodeMessage(content: #"[{"type": "compaction", "content": null, "encrypted_content": "e"}]"#).content.first)
        let sent = try XCTUnwrap(try json(block.asRequestParam()) as? [String: Any])
        XCTAssertNil(sent["signature"])
        XCTAssertNil(sent["tool_changes"])
        XCTAssertEqual(sent["encrypted_content"] as? String, "e")
    }

    // MARK: - mcp_tool_listing

    private let listingWire = """
    [{"type": "mcp_tool_listing", "mcp_server_name": "docs", "tools": [
        {"name": "search", "description": "Search docs", "input_schema": {"type": "object", "properties": {"max_results": {"type": "integer"}}}},
        {"name": "fetch", "input_schema": {"type": "object"}}
    ]}]
    """

    func testMcpToolListingBlockDecodes() throws {
        guard case .mcpToolListing(let block) = try decodeMessage(content: listingWire).content.first else {
            return XCTFail("expected .mcpToolListing")
        }
        XCTAssertEqual(block.mcpServerName, "docs")
        XCTAssertEqual(block.tools.map(\.name), ["search", "fetch"])
        XCTAssertEqual(block.tools[0].description, "Search docs")
        XCTAssertNil(block.tools[1].description)
    }

    func testMcpToolListingRoundTripsIntoAParamAndPinsAToolset() throws {
        guard case .mcpToolListing(let block) = try decodeMessage(content: listingWire).content.first else {
            return XCTFail("expected .mcpToolListing")
        }
        // Echoing the assistant message back, listing included, is what pins the listing for later requests.
        let echoed = try XCTUnwrap(try json(try XCTUnwrap(try decodeMessage(content: listingWire).content.first).asRequestParam()) as? [String: Any])
        XCTAssertEqual(echoed["type"] as? String, "mcp_tool_listing")
        XCTAssertEqual(echoed["mcp_server_name"] as? String, "docs")
        XCTAssertEqual((echoed["tools"] as? [[String: Any]])?.count, 2)

        // ...and the same listing can be pinned directly on the toolset, skipping the server round trip.
        let pinned = BetaMCPToolsetParam(
            mcpServerName: block.mcpServerName,
            tools: block.tools.map { BetaMCPToolParam(name: $0.name, inputSchema: $0.inputSchema, description: $0.description) }
        )
        let sent = try XCTUnwrap(try json(pinned) as? [String: Any])
        let tools = try XCTUnwrap(sent["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.map { $0["name"] as? String }, ["search", "fetch"])
        let props = ((tools[0]["input_schema"] as? [String: Any])?["properties"] as? [String: Any])
        XCTAssertNotNil(props?["max_results"], "snake_case schema property names must be untouched")
    }

    func testToolsetWithoutPinnedToolsOmitsTheKey() throws {
        let sent = try XCTUnwrap(try json(BetaMCPToolsetParam(mcpServerName: "docs")) as? [String: Any])
        XCTAssertNil(sent["tools"])
    }

    // MARK: - tool_addition by definition

    func testToolAdditionEncodesByReferenceAndByDefinition() throws {
        let byReference = try XCTUnwrap(try json(
            BetaRequestToolAdditionBlockParam(tool: .tool(BetaToolChangeToolReferenceParam(name: "echo")))
        ) as? [String: Any])
        XCTAssertEqual(byReference["type"] as? String, "tool_addition")
        XCTAssertEqual((byReference["tool"] as? [String: Any])?["type"] as? String, "tool_reference")

        let byDefinition = try XCTUnwrap(try json(BetaRequestToolAdditionBlockParam(
            definition: .tool(.custom(ToolParam(name: "echo", inputSchema: .object(["type": .string("object")]))))
        )) as? [String: Any])
        let tool = try XCTUnwrap(byDefinition["tool"] as? [String: Any])
        XCTAssertEqual(tool["type"] as? String, "tool_definition")
        XCTAssertEqual((tool["definition"] as? [String: Any])?["name"] as? String, "echo")
    }

    // MARK: - thinking

    func testEveryBetaThinkingConfigEncodes() throws {
        func encoded(_ config: BetaThinkingConfigParam) throws -> NSDictionary {
            try XCTUnwrap(try json(config) as? NSDictionary)
        }
        XCTAssertEqual(try encoded(.disabled(BetaThinkingConfigDisabledParam())), ["type": "disabled"])
        XCTAssertEqual(try encoded(.betweenTools(BetaThinkingConfigBetweenToolsParam())), ["type": "between_tools"])
        XCTAssertEqual(try encoded(.enabled(BetaThinkingConfigEnabledParam(budgetTokens: 2048))),
                       ["type": "enabled", "budget_tokens": 2048])
        XCTAssertEqual(
            try encoded(.adaptive(BetaThinkingConfigAdaptiveParam(
                blockBinding: BetaThinkingBlockBindingParam(prefixMismatchBehavior: .dropBlock), display: .updates
            ))),
            ["type": "adaptive", "display": "updates", "block_binding": ["prefix_mismatch_behavior": "drop_block"]]
        )
    }

    func testGAThinkingConfigConvertsForExistingCallSites() throws {
        XCTAssertEqual(
            BetaThinkingConfigParam(.enabled(ThinkingConfigEnabledParam(budgetTokens: 1500, display: .omitted))),
            .enabled(BetaThinkingConfigEnabledParam(budgetTokens: 1500, display: .omitted))
        )
        XCTAssertEqual(BetaThinkingConfigParam(.disabled(ThinkingConfigDisabledParam())), .disabled(BetaThinkingConfigDisabledParam()))
        XCTAssertEqual(BetaThinkingConfigParam(.betweenTools(ThinkingConfigBetweenToolsParam())), .betweenTools(BetaThinkingConfigBetweenToolsParam()))
        XCTAssertEqual(BetaThinkingConfigParam(.adaptive(ThinkingConfigAdaptiveParam(display: .summarized))), .adaptive(BetaThinkingConfigAdaptiveParam(display: .summarized)))
    }

    // MARK: - request params

    func testCompactionDiagnosticsAndThinkingAreSentInTheCreateBody() throws {
        let params = BetaMessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 16, messages: [.user("Hi")],
            compaction: BetaCompactionConfigParam(instructions: "keep decisions"),
            diagnostics: DiagnosticsParam(),
            thinking: .betweenTools(BetaThinkingConfigBetweenToolsParam())
        )
        let sent = try XCTUnwrap(try json(params) as? [String: Any])
        XCTAssertEqual(sent["compaction"] as? NSDictionary, ["type": "summarize", "instructions": "keep decisions"])
        XCTAssertEqual((sent["thinking"] as? [String: Any])?["type"] as? String, "between_tools")
        let diagnostics = try XCTUnwrap(sent["diagnostics"] as? [String: Any])
        XCTAssertTrue(diagnostics["previous_message_id"] is NSNull, "first-turn opt-in must send an explicit null")
    }

    func testWithPreservesEveryBetaCreateField() throws {
        let full = BetaMessageCreateParams(
            model: "claude-opus-5-5", maxTokens: 99, messages: [.user("Hi")],
            cacheControl: CacheControlEphemeral(ttl: .oneHour),
            compaction: BetaCompactionConfigParam(instructions: "x"),
            container: .id("c_1"),
            contextManagement: .object(["edits": .array([])]),
            diagnostics: DiagnosticsParam(previousMessageId: "msg_prev"),
            fallbackCreditToken: "tok",
            fallbacks: .array([]),
            inferenceGeo: "us",
            mcpServers: [BetaRequestMCPServerURLDefinitionParam(name: "docs", url: "https://m.example")],
            metadata: MetadataParam(userId: "u"),
            outputConfig: BetaOutputConfigParam(),
            serviceTier: .standardOnly,
            speed: .fast,
            stopSequences: ["STOP"],
            system: .text("sys"),
            thinking: .enabled(BetaThinkingConfigEnabledParam(budgetTokens: 2048)),
            toolChoice: .auto(ToolChoiceAutoParam()),
            tools: [.tool(.custom(ToolParam(name: "t", inputSchema: .object([:]))))]
        )
        for child in Mirror(reflecting: full).children {
            XCTAssertFalse(String(describing: child.value) == "nil", "fixture leaves `\(child.label ?? "?")` unset; populate it")
        }
        XCTAssertEqual(full.with(messages: [.user("Hi")], tools: nil), full)
        XCTAssertEqual(full.with(messages: [.user("next")]).compaction, BetaCompactionConfigParam(instructions: "x"))
    }

    func testCountTokensParamsAcceptCompactionAndBetaThinking() throws {
        let params = BetaMessageCountTokensParams(
            model: "claude-opus-5-5", messages: [.user("Hi")],
            compaction: BetaCompactionConfigParam(), thinking: .betweenTools(BetaThinkingConfigBetweenToolsParam())
        )
        let sent = try XCTUnwrap(try json(params) as? [String: Any])
        XCTAssertEqual((sent["compaction"] as? [String: Any])?["type"] as? String, "summarize")
        XCTAssertEqual((sent["thinking"] as? [String: Any])?["type"] as? String, "between_tools")
    }
}
