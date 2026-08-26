import Foundation

/// Drives one Messages SSE response to completion, exposing it as `MessageStreamEvent`s plus a
/// few convenience views. One driver `Task` reads the underlying network body exactly once --
/// decoding SSE, accumulating a growing `Message` snapshot, and deriving higher-level events --
/// and publishes every derived event to a `Broadcast` so `.events`/`.textStream` can each be
/// consumed independently. Roughly the Swift analogue of the reference SDKs' `MessageStream`, but
/// without their single-iterator restriction, since `Broadcast` allows any number of subscribers.
public final class MessageStream: Sendable {
    public let response: HTTPURLResponse

    private let broadcast = Broadcast<MessageStreamEvent>()
    private let finalMessageTask: Task<Message, Error>

    init(response: HTTPURLResponse, sse: AsyncThrowingStream<ServerSentEvent, Error>) {
        self.response = response
        let broadcast = self.broadcast
        self.finalMessageTask = Task {
            var accumulator = MessageAccumulator()
            do {
                for try await sseEvent in sse {
                    guard let raw = try MessagesSSE.translate(sseEvent, response: response) else { continue }
                    let snapshot = try accumulator.accumulate(raw)
                    for event in try buildMessageStreamEvents(for: raw, snapshot: snapshot) {
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
    public var events: AsyncThrowingStream<MessageStreamEvent, Error> {
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

    /// Awaits the end of the stream and returns the fully-accumulated `Message`.
    public func finalMessage() async throws -> Message {
        try await finalMessageTask.value
    }

    /// Stops reading the underlying response; in-flight subscribers finish with `CancellationError`.
    public func cancel() {
        finalMessageTask.cancel()
    }
}
