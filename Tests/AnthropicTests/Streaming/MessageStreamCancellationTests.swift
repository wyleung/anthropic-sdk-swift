import XCTest
@testable import Anthropic

/// Regression coverage for the fix to `MessageStream.finalMessageTask`: cancelling the stream
/// must always surface as a thrown `CancellationError`, even when the underlying SSE sequence
/// ends "successfully" (via `continuation.finish()`) rather than throwing -- which is how
/// `URLSession.bytes(for:)`-backed streams actually behave on cancellation in practice.
final class MessageStreamCancellationTests: XCTestCase {
    private static let response = HTTPURLResponse(
        url: URL(string: "https://api.anthropic.com/v1/messages")!, statusCode: 200, httpVersion: nil,
        headerFields: ["content-type": "text/event-stream"]
    )!

    private static let messageStartEvent = ServerSentEvent(
        event: "message_start",
        data: #"""
        {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5","content":[],"usage":{"input_tokens":10,"output_tokens":0}}}
        """#,
        raw: []
    )

    func testCancelThrowsCancellationErrorEvenIfTheUnderlyingStreamEndsSuccessfully() async throws {
        var continuation: AsyncThrowingStream<ServerSentEvent, Error>.Continuation!
        let sse = AsyncThrowingStream<ServerSentEvent, Error> { continuation = $0 }
        let stream = MessageStream(response: Self.response, sse: sse)

        continuation.yield(Self.messageStartEvent)
        // Give the driver Task a chance to consume `message_start` and populate the accumulator
        // -- without this, the bug this test guards against wouldn't even have a message to
        // fabricate a truncated response from.
        try await Task.sleep(nanoseconds: 20_000_000)

        stream.cancel()
        // The underlying transport reacts to cancellation the way `URLSession.bytes(for:)` does
        // in practice: the sequence ends "successfully" rather than throwing `CancellationError`
        // itself. Before the fix, `finalMessageTask`'s `for try await` loop treated this as a
        // normal end-of-stream and returned a truncated (but structurally valid) `Message`.
        continuation.finish()

        do {
            _ = try await stream.finalMessage()
            XCTFail("expected finalMessage() to throw CancellationError")
        } catch is CancellationError {
            // expected
        }
    }

    func testCancelBeforeAnyEventStillThrowsCancellationErrorRatherThanResponseValidation() async throws {
        var continuation: AsyncThrowingStream<ServerSentEvent, Error>.Continuation!
        let sse = AsyncThrowingStream<ServerSentEvent, Error> { continuation = $0 }
        let stream = MessageStream(response: Self.response, sse: sse)

        stream.cancel()
        continuation.finish()

        do {
            _ = try await stream.finalMessage()
            XCTFail("expected finalMessage() to throw CancellationError")
        } catch is CancellationError {
            // expected -- not `AnthropicError.responseValidation`, which is what a normal
            // (non-cancelled) empty stream throws.
        }
    }
}
