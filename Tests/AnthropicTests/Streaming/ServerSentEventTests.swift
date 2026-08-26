import XCTest
@testable import Anthropic

final class ServerSentEventTests: XCTestCase {
    func testDecoderJoinsMultiLineDataAndFlushesOnBlankLine() {
        var decoder = SSEDecoder()
        XCTAssertNil(decoder.decode("event: message_start"))
        XCTAssertNil(decoder.decode(#"data: {"foo":"#))
        XCTAssertNil(decoder.decode("data: 1}"))
        let event = decoder.decode("")
        XCTAssertEqual(event?.event, "message_start")
        XCTAssertEqual(event?.data, "{\"foo\":\n1}")
        XCTAssertEqual(event?.raw, [#"event: message_start"#, #"data: {"foo":"#, "data: 1}"])
    }

    func testDecoderIgnoresCommentLinesButKeepsThemInRaw() {
        var decoder = SSEDecoder()
        XCTAssertNil(decoder.decode(": this is a comment"))
        XCTAssertNil(decoder.decode("data: hello"))
        let event = decoder.decode("")
        XCTAssertEqual(event?.data, "hello")
        XCTAssertEqual(event?.raw, [": this is a comment", "data: hello"])
    }

    func testDecoderStripsTrailingCarriageReturn() {
        var decoder = SSEDecoder()
        XCTAssertNil(decoder.decode("data: hello\r"))
        let event = decoder.decode("\r")
        XCTAssertEqual(event?.data, "hello")
    }

    func testDecoderIgnoresRepeatedBlankLines() {
        var decoder = SSEDecoder()
        XCTAssertNil(decoder.decode(""))
        XCTAssertNil(decoder.decode("data: hello"))
        XCTAssertNotNil(decoder.decode(""))
        XCTAssertNil(decoder.decode(""))
    }

    func testSseEventsDecodesMultipleEvents() async throws {
        let lines = StringLines(lines: [
            "event: message_stop", #"data: {"type":"message_stop"}"#, "",
            "event: ping", "data: {}", "",
        ])
        var events: [ServerSentEvent] = []
        for try await event in sseEvents(from: lines) {
            events.append(event)
        }
        XCTAssertEqual(events.map(\.event), ["message_stop", "ping"])
    }

    func testSseEventsDropsAnIncompleteTrailingEventWithNoFinalBlankLine() async throws {
        // Matches both reference decoders: an event only completes on a blank line, so a stream
        // that ends mid-event (no server ever does this) silently drops the dangling fragment
        // rather than force-flushing it.
        let lines = StringLines(lines: ["event: ping", "data: {}"])
        var events: [ServerSentEvent] = []
        for try await event in sseEvents(from: lines) {
            events.append(event)
        }
        XCTAssertTrue(events.isEmpty)
    }

    func testSseLinesPreservesBlankLinesUnlikeFoundationsAsyncLineSequence() async throws {
        // The whole reason sseLines exists: Foundation's `AsyncLineSequence` (which backs both
        // `URLSession.AsyncBytes.lines` and `FileHandle.bytes.lines`) silently drops every blank
        // line, which would make SSEDecoder never flush a single event against a real response.
        let bytes = ByteSequence("event: message_start\ndata: {}\n\nevent: ping\ndata: {}\n\n")
        var lines: [String] = []
        for try await line in sseLines(from: bytes) {
            lines.append(line)
        }
        XCTAssertEqual(lines, [
            "event: message_start", "data: {}", "",
            "event: ping", "data: {}", "",
        ])
    }

    func testSseLinesYieldsAFinalUnterminatedLine() async throws {
        let bytes = ByteSequence("event: ping\ndata: {}")
        var lines: [String] = []
        for try await line in sseLines(from: bytes) {
            lines.append(line)
        }
        XCTAssertEqual(lines, ["event: ping", "data: {}"])
    }

    func testSseLinesEndToEndThroughSseEventsRecoversBothEvents() async throws {
        // The integration-level regression check: raw bytes containing blank-line-delimited SSE
        // events, run through the real production pipeline (sseLines -> sseEvents), decode both
        // events -- proving the fix works together, not just in isolated pieces.
        let bytes = ByteSequence(
            "event: message_start\ndata: {\"type\":\"message_start\"}\n\nevent: message_stop\ndata: {}\n\n"
        )
        var events: [ServerSentEvent] = []
        for try await event in sseEvents(from: sseLines(from: bytes)) {
            events.append(event)
        }
        XCTAssertEqual(events.map(\.event), ["message_start", "message_stop"])
    }
}
