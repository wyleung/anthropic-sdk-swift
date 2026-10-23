import XCTest
@testable import Anthropic
@testable import AnthropicBeta

/// `clear_at` and `output_config` arrived on `role: "system"` messages after the first port of
/// `BetaMessageParam`; without them a system message could not say how long its text stays in front of the
/// model or set a per-turn effort.
final class BetaSystemMessageParamTests: XCTestCase {
    private func wire(_ message: BetaMessageParam) throws -> NSDictionary {
        let data = try HTTPTransport.encoder.encode(message)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    private let text: BetaContentBlockParam = .standard(.text(TextBlockParam(text: "Be brief.")))

    func testASystemMessageCarriesClearAtAndOutputConfig() throws {
        let message = BetaMessageParam(
            role: .system, content: [text], clearAt: .nextUserMessage,
            outputConfig: BetaSystemMessageOutputConfigParam(effort: .high)
        )

        XCTAssertEqual(try wire(message), [
            "role": "system",
            "content": [["type": "text", "text": "Be brief."]],
            "clear_at": "next_user_message",
            "output_config": ["effort": "high"],
        ])
    }

    func testClearAtNeverIsSentExplicitly() throws {
        let message = BetaMessageParam(role: .system, content: [text], clearAt: BetaSystemMessageClearAt.never)

        XCTAssertEqual(try wire(message)["clear_at"] as? String, "never")
    }

    func testAnEmptyOutputConfigIsSentAsAnEmptyObjectOnAMessageThatCarriesContent() throws {
        let message = BetaMessageParam(role: .system, content: [text], outputConfig: BetaSystemMessageOutputConfigParam())

        XCTAssertEqual(try wire(message)["output_config"] as? NSDictionary, [:])
    }

    /// `content` is optional on a system message, and an empty list reads as a message with no content.
    func testASystemMessageWithOnlyAnOutputConfigLeavesContentOut() throws {
        let message = BetaMessageParam(
            role: .system, content: [], outputConfig: BetaSystemMessageOutputConfigParam(effort: .low)
        )

        XCTAssertEqual(try wire(message), ["role": "system", "output_config": ["effort": "low"]])
    }

    func testMessagesThatUseNeitherFieldEncodeExactlyAsBefore() throws {
        XCTAssertEqual(try wire(.user("Hi")), ["role": "user", "content": [["type": "text", "text": "Hi"]]])
        XCTAssertEqual(try wire(.system("Be brief.")), ["role": "system", "content": [["type": "text", "text": "Be brief."]]])
        // No new keys, and an empty content list is still sent where nothing says to leave it out.
        XCTAssertEqual(try wire(BetaMessageParam(role: .user, content: [])), ["role": "user", "content": []])
        XCTAssertEqual(try wire(BetaMessageParam(role: .system, content: [])), ["role": "system", "content": []])
    }

    func testTheFieldsParticipateInEquality() {
        let plain = BetaMessageParam(role: .system, content: [text])
        XCTAssertNotEqual(plain, BetaMessageParam(role: .system, content: [text], clearAt: .nextUserMessage))
        XCTAssertNotEqual(
            plain, BetaMessageParam(role: .system, content: [text], outputConfig: BetaSystemMessageOutputConfigParam(effort: .max))
        )
    }

    func testEveryEffortLevelReachesTheWire() throws {
        for level in [EffortLevel.low, .medium, .high, .xhigh, .max] {
            let message = BetaMessageParam(
                role: .system, content: [], outputConfig: BetaSystemMessageOutputConfigParam(effort: level)
            )
            XCTAssertEqual((try wire(message)["output_config"] as? NSDictionary)?["effort"] as? String, level.rawValue)
        }
    }
}
