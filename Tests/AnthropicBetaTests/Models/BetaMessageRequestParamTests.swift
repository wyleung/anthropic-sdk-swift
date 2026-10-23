import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// `BetaMessage.asRequestParam()`: the server-tool blocks Beta shares with GA go through the same
/// converters (they live in the GA module), and Beta additionally passes a block it does not model
/// through raw, where GA has to throw.
final class BetaMessageRequestParamTests: XCTestCase {
    private static let blocks: [(kind: String, json: String)] = [
        ("text", #"{"type":"text","text":"Let me check."}"#),
        ("thinking", #"{"type":"thinking","thinking":"hmm","signature":"sig-1"}"#),
        ("redacted_thinking", #"{"type":"redacted_thinking","data":"opaque"}"#),
        ("tool_use", #"{"type":"tool_use","id":"toolu_1","name":"get_weather","input":{"city":"Paris"}}"#),
        ("server_tool_use", #"{"type":"server_tool_use","id":"srvtoolu_1","name":"web_search","input":{"query":"x"}}"#),
        (
            "web_search_tool_result",
            #"{"type":"web_search_tool_result","tool_use_id":"srvtoolu_1","content":[{"type":"web_search_result","title":"T","url":"https://e.com","encrypted_content":"enc","page_age":"1 day"}]}"#
        ),
        (
            "web_fetch_tool_result",
            #"{"type":"web_fetch_tool_result","tool_use_id":"srvtoolu_2","content":{"type":"web_fetch_result","url":"https://e.com","retrieved_at":"2026-01-01T00:00:00Z","content":{"type":"document","title":"Doc","source":{"type":"text","media_type":"text/plain","data":"body"},"citations":{"enabled":true}}}}"#
        ),
        (
            "code_execution_tool_result",
            #"{"type":"code_execution_tool_result","tool_use_id":"srvtoolu_3","content":{"type":"code_execution_result","stdout":"hi","stderr":"","return_code":0,"content":[{"type":"code_execution_output","file_id":"file_1"}]}}"#
        ),
        (
            "bash_code_execution_tool_result",
            #"{"type":"bash_code_execution_tool_result","tool_use_id":"srvtoolu_4","content":{"type":"bash_code_execution_result","stdout":"ok","stderr":"","return_code":0,"content":[{"type":"bash_code_execution_output","file_id":"file_2"}]}}"#
        ),
        (
            "text_editor_code_execution_tool_result",
            #"{"type":"text_editor_code_execution_tool_result","tool_use_id":"srvtoolu_5","content":{"type":"text_editor_code_execution_view_result","content":"file text","file_type":"text","num_lines":1,"start_line":1,"total_lines":1}}"#
        ),
        (
            "tool_search_tool_result",
            #"{"type":"tool_search_tool_result","tool_use_id":"srvtoolu_6","content":{"type":"tool_search_tool_search_result","tool_references":[{"type":"tool_reference","tool_name":"calc"}]}}"#
        ),
        ("container_upload", #"{"type":"container_upload","file_id":"file_9"}"#),
    ]

    private func decodeMessage(content: [String]) throws -> BetaMessage {
        let json = """
        {"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5-5","content":[\(content.joined(separator: ","))],
         "stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}
        """
        return try HTTPTransport.decoder.decode(BetaMessage.self, from: Data(json.utf8))
    }

    private func object(_ json: String) throws -> NSDictionary {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)
    }

    func testEverySharedBlockKindIsEchoedBackExactlyAsReceived() throws {
        for (kind, json) in Self.blocks {
            let param = try decodeMessage(content: [json]).asRequestParam()

            XCTAssertEqual(param.role, .assistant, kind)
            let encoded = try HTTPTransport.encoder.encode(param.content)
            let echoed = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [NSDictionary], kind)
            XCTAssertEqual(echoed, [try object(json)], "\(kind) was altered on the way back")
        }
    }

    func testABlockOfAnUnmodeledTypeIsPassedThroughRaw() throws {
        let unknown = #"{"type":"brand_new_block","x":1,"nested":{"y":[1,2]}}"#
        let param = try decodeMessage(content: [Self.blocks[0].json, unknown]).asRequestParam()

        let encoded = try HTTPTransport.encoder.encode(param.content)
        let echoed = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [NSDictionary])
        XCTAssertEqual(echoed, [try object(Self.blocks[0].json), try object(unknown)])
    }
}
