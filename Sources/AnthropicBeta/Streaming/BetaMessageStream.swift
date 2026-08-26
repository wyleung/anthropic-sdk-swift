import Foundation
import Anthropic

/// The Beta analogue of GA's `MessageStream`: drives one Beta Messages SSE response to
/// completion, exposing it as `BetaMessageStreamEvent`s plus the same convenience views, backed
/// by the same `Broadcast` multi-subscriber design.
public final class BetaMessageStream: Sendable {
    public let response: HTTPURLResponse

    private let broadcast = Broadcast<BetaMessageStreamEvent>()
    private let finalMessageTask: Task<BetaMessage, Error>

    init(response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>) {
        self.response = response
        let broadcast = self.broadcast
        self.finalMessageTask = Task {
            var accumulator = BetaMessageAccumulator()
            do {
                for try await sseEvent in sse {
                    guard let raw = try BetaMessagesSSE.translate(sseEvent, response: response) else { continue }
                    let snapshot = try accumulator.accumulate(raw)
                    for event in try buildBetaMessageStreamEvents(for: raw, snapshot: snapshot) {
                        await broadcast.publish(event)
                    }
                }
            } catch {
                await broadcast.finish(throwing: error)
                throw error
            }
            await broadcast.finish()
            guard let message = accumulator.snapshot else {
                let error = AnthropicError.responseValidation(
                    message: "The stream ended before a message_start event was received.",
                    body: nil
                )
                throw error
            }
            return message
        }
    }

    /// Every higher-level stream event, from the beginning, no matter when this is called.
    public var events: AsyncThrowingStream<BetaMessageStreamEvent, Error> {
        get async { await broadcast.subscribe() }
    }

    /// Just the incremental assistant-visible text, derived from `.text` events.
    public var textStream: AsyncThrowingStream<String, Error> {
        get async {
            let events = await broadcast.subscribe()
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await event in events {
                            if case .text(let textEvent) = event {
                                continuation.yield(textEvent.text)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    /// Awaits the end of the stream and returns the fully-accumulated `BetaMessage`.
    public func finalMessage() async throws -> BetaMessage {
        try await finalMessageTask.value
    }

    /// Stops reading the underlying response; in-flight subscribers finish with `CancellationError`.
    public func cancel() {
        finalMessageTask.cancel()
    }
}
