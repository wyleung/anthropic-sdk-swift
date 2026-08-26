import XCTest
@testable import Anthropic
@testable import AnthropicBeta

final class BetaContentBlockTests: XCTestCase {
    private func decode(_ json: String) throws -> BetaContentBlock {
        try HTTPTransport.decoder.decode(BetaContentBlock.self, from: Data(json.utf8))
    }

    // MARK: - mcp_tool_use

    func testDecodesMCPToolUse() throws {
        let block = try decode(#"""
        {"type":"mcp_tool_use","id":"mcptoolu_1","name":"search","server_name":"docs","input":{"q":"swift"}}
        """#)
        guard case .mcpToolUse(let mcpToolUse) = block else {
            return XCTFail("expected an mcp_tool_use block")
        }
        XCTAssertEqual(mcpToolUse.id, "mcptoolu_1")
        XCTAssertEqual(mcpToolUse.name, "search")
        XCTAssertEqual(mcpToolUse.serverName, "docs")
        XCTAssertEqual(mcpToolUse.input, ["q": .string("swift")])
    }

    func testMCPToolUseRoundTripsThroughAsRequestParam() throws {
        let block = try decode(#"""
        {"type":"mcp_tool_use","id":"mcptoolu_1","name":"search","server_name":"docs","input":{"q":"swift"}}
        """#)
        guard case .mcpToolUse(let param) = try block.asRequestParam() else {
            return XCTFail("expected an mcp_tool_use param")
        }
        XCTAssertEqual(param.id, "mcptoolu_1")
        XCTAssertEqual(param.name, "search")
        XCTAssertEqual(param.serverName, "docs")
        XCTAssertEqual(param.input, ["q": .string("swift")])
    }

    // MARK: - mcp_tool_result

    func testDecodesMCPToolResultWithTextContent() throws {
        let block = try decode(#"""
        {"type":"mcp_tool_result","tool_use_id":"toolu_1","is_error":false,"content":"plain text result"}
        """#)
        guard case .mcpToolResult(let mcpToolResult) = block else {
            return XCTFail("expected an mcp_tool_result block")
        }
        XCTAssertEqual(mcpToolResult.toolUseId, "toolu_1")
        XCTAssertEqual(mcpToolResult.isError, false)
        XCTAssertEqual(mcpToolResult.content, .text("plain text result"))
    }

    func testDecodesMCPToolResultWithBlockContent() throws {
        let block = try decode(#"""
        {"type":"mcp_tool_result","tool_use_id":"toolu_2","is_error":true,
        "content":[{"type":"text","text":"oops"}]}
        """#)
        guard case .mcpToolResult(let mcpToolResult) = block else {
            return XCTFail("expected an mcp_tool_result block")
        }
        XCTAssertEqual(mcpToolResult.isError, true)
        XCTAssertEqual(mcpToolResult.content, .blocks([TextBlock(text: "oops")]))
    }

    func testMCPToolResultRoundTripsThroughAsRequestParam() throws {
        let block = try decode(#"""
        {"type":"mcp_tool_result","tool_use_id":"toolu_1","is_error":false,"content":"plain text result"}
        """#)
        guard case .mcpToolResult(let param) = try block.asRequestParam() else {
            return XCTFail("expected an mcp_tool_result param")
        }
        XCTAssertEqual(param.toolUseId, "toolu_1")
        XCTAssertEqual(param.isError, false)
        XCTAssertEqual(param.content, .text("plain text result"))
    }

    // MARK: - compaction

    func testDecodesCompactionWithContent() throws {
        let block = try decode(#"""
        {"type":"compaction","content":"summary text","encrypted_content":null}
        """#)
        guard case .compaction(let compaction) = block else {
            return XCTFail("expected a compaction block")
        }
        XCTAssertEqual(compaction.content, "summary text")
        XCTAssertNil(compaction.encryptedContent)
    }

    func testDecodesCompactionWithNilContentMeaningFailedSummary() throws {
        let block = try decode(#"""
        {"type":"compaction","content":null,"encrypted_content":"enc123"}
        """#)
        guard case .compaction(let compaction) = block else {
            return XCTFail("expected a compaction block")
        }
        XCTAssertNil(compaction.content)
        XCTAssertEqual(compaction.encryptedContent, "enc123")
    }

    func testCompactionRoundTripsThroughAsRequestParam() throws {
        let block = try decode(#"""
        {"type":"compaction","content":"summary text","encrypted_content":"enc123"}
        """#)
        guard case .compaction(let param) = try block.asRequestParam() else {
            return XCTFail("expected a compaction param")
        }
        XCTAssertEqual(param.content, "summary text")
        XCTAssertEqual(param.encryptedContent, "enc123")
    }

    // MARK: - fallback

    func testDecodesFallbackWithAKnownTriggerCategory() throws {
        let block = try decode(#"""
        {"type":"fallback","to":{"model":"claude-opus-5"},"from":{"model":"claude-sonnet-5"},
        "trigger":{"type":"refusal","category":"cyber"}}
        """#)
        guard case .fallback(let fallback) = block else {
            return XCTFail("expected a fallback block")
        }
        XCTAssertEqual(fallback.to.model, "claude-opus-5")
        XCTAssertEqual(fallback.from.model, "claude-sonnet-5")
        XCTAssertEqual(fallback.trigger.category, .cyber)
    }

    func testDecodesFallbackWithAnUnknownTriggerCategory() throws {
        let block = try decode(#"""
        {"type":"fallback","to":{"model":"claude-opus-5"},"from":{"model":"claude-sonnet-5"},
        "trigger":{"type":"refusal","category":"something_new"}}
        """#)
        guard case .fallback(let fallback) = block else {
            return XCTFail("expected a fallback block")
        }
        XCTAssertEqual(fallback.trigger.category, .unknown("something_new"))
    }

    func testFallbackRoundTripsThroughAsRequestParam() throws {
        let block = try decode(#"""
        {"type":"fallback","to":{"model":"claude-opus-5"},"from":{"model":"claude-sonnet-5"},
        "trigger":{"type":"refusal","category":"cyber"}}
        """#)
        guard case .fallback(let param) = try block.asRequestParam() else {
            return XCTFail("expected a fallback param")
        }
        XCTAssertEqual(param.to.model, "claude-opus-5")
        XCTAssertEqual(param.from?.model, "claude-sonnet-5")
        guard case .object(let trigger) = param.trigger else {
            return XCTFail("expected the trigger to round-trip as a JSONValue object")
        }
        XCTAssertEqual(trigger["category"], .string("cyber"))
        XCTAssertEqual(trigger["type"], .string("refusal"))
    }

    // MARK: - advisor_tool_result

    func testDecodesAdvisorToolResultWithAResult() throws {
        let block = try decode(#"""
        {"type":"advisor_tool_result","tool_use_id":"toolu_3",
        "content":{"type":"advisor_result","text":"advice","stop_reason":"end_turn"}}
        """#)
        guard case .advisorToolResult(let advisorToolResult) = block else {
            return XCTFail("expected an advisor_tool_result block")
        }
        XCTAssertEqual(advisorToolResult.toolUseId, "toolu_3")
        XCTAssertEqual(advisorToolResult.content, .result(BetaAdvisorResultBlock(text: "advice", stopReason: "end_turn")))
    }

    func testDecodesAdvisorToolResultWithARedactedResult() throws {
        let block = try decode(#"""
        {"type":"advisor_tool_result","tool_use_id":"toolu_4",
        "content":{"type":"advisor_redacted_result","encrypted_content":"enc","stop_reason":null}}
        """#)
        guard case .advisorToolResult(let advisorToolResult) = block else {
            return XCTFail("expected an advisor_tool_result block")
        }
        XCTAssertEqual(
            advisorToolResult.content,
            .redactedResult(BetaAdvisorRedactedResultBlock(encryptedContent: "enc", stopReason: nil))
        )
    }

    func testDecodesAdvisorToolResultWithAnError() throws {
        let block = try decode(#"""
        {"type":"advisor_tool_result","tool_use_id":"toolu_5",
        "content":{"type":"advisor_tool_result_error","error_code":"overloaded"}}
        """#)
        guard case .advisorToolResult(let advisorToolResult) = block else {
            return XCTFail("expected an advisor_tool_result block")
        }
        XCTAssertEqual(advisorToolResult.content, .error(BetaAdvisorToolResultError(errorCode: .overloaded)))
    }

    func testAdvisorToolResultRoundTripsThroughAsRequestParam() throws {
        let block = try decode(#"""
        {"type":"advisor_tool_result","tool_use_id":"toolu_3",
        "content":{"type":"advisor_result","text":"advice","stop_reason":"end_turn"}}
        """#)
        guard case .advisorToolResult(let param) = try block.asRequestParam() else {
            return XCTFail("expected an advisor_tool_result param")
        }
        XCTAssertEqual(param.toolUseId, "toolu_3")
        XCTAssertEqual(param.content, .result(BetaAdvisorResultBlock(text: "advice", stopReason: "end_turn")))
    }

    // MARK: - unknown

    func testUnknownBlockTypeFallsBackToUnknownCase() throws {
        let block = try decode(#"{"type":"some_new_block","foo":"bar"}"#)
        guard case .unknown(let type, let raw) = block else {
            return XCTFail("expected an unknown block")
        }
        XCTAssertEqual(type, "some_new_block")
        XCTAssertEqual(raw, .object(["type": .string("some_new_block"), "foo": .string("bar")]))
    }

    func testUnknownBlockRoundTripsThroughAsRequestParamAsRaw() throws {
        let block = try decode(#"{"type":"some_new_block","foo":"bar"}"#)
        guard case .raw(let raw) = try block.asRequestParam() else {
            return XCTFail("expected a raw param")
        }
        XCTAssertEqual(raw, .object(["type": .string("some_new_block"), "foo": .string("bar")]))
    }

    // MARK: - mcpServers

    func testMCPServersFieldEncodesToSnakeCase() throws {
        let params = BetaMessageCreateParams(
            model: "claude-opus-5", maxTokens: 256, messages: [.user("Hi")],
            mcpServers: [
                BetaRequestMCPServerURLDefinitionParam(
                    name: "docs", url: "https://mcp.example.com", authorizationToken: "tok",
                    toolConfiguration: BetaRequestMCPServerToolConfigurationParam(allowedTools: ["search"], enabled: true)
                )
            ]
        )
        let data = try HTTPTransport.encoder.encode(params)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let servers = try XCTUnwrap(json["mcp_servers"] as? [[String: Any]])
        XCTAssertEqual(servers.first?["name"] as? String, "docs")
        XCTAssertEqual(servers.first?["url"] as? String, "https://mcp.example.com")
        XCTAssertEqual(servers.first?["authorization_token"] as? String, "tok")
        let toolConfiguration = try XCTUnwrap(servers.first?["tool_configuration"] as? [String: Any])
        XCTAssertEqual(toolConfiguration["allowed_tools"] as? [String], ["search"])
        XCTAssertEqual(toolConfiguration["enabled"] as? Bool, true)
    }
}
