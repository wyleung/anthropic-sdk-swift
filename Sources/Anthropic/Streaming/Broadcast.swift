/// Lets any number of independent consumers each get their own replay-then-live `AsyncSequence`
/// view over one underlying producer, working around `AsyncSequence` being single-consumer by
/// default. `MessageStream` uses this to let `.events`, `.textStream`, etc. all be requested
/// independently while the driver `Task` reads the network body exactly once.
///
/// Every subscriber replays the full history published so far, then receives new elements live.
/// A subscriber that arrives after `finish()` replays history and immediately completes/throws --
/// it never misses elements, since `subscribe()` and `publish`/`finish` are all actor-isolated and
/// none of `subscribe()`'s work suspends before either capturing the current history+terminal
/// state or registering for future pushes, so no element can be published in the gap between them.
package actor Broadcast<Element: Sendable> {
    private var history: [Element] = []
    private var terminal: Result<Void, Error>?
    private var continuations: [Int: AsyncThrowingStream<Element, Error>.Continuation] = [:]
    private var nextSubscriberID = 0

    package init() {}

    package func publish(_ element: Element) {
        history.append(element)
        for continuation in continuations.values {
            continuation.yield(element)
        }
    }

    package func finish(throwing error: Error? = nil) {
        guard terminal == nil else { return }
        terminal = error.map(Result.failure) ?? .success(())
        for continuation in continuations.values {
            continuation.finish(throwing: error)
        }
        continuations.removeAll()
    }

    package func subscribe() -> AsyncThrowingStream<Element, Error> {
        let id = nextSubscriberID
        nextSubscriberID += 1
        return AsyncThrowingStream { continuation in
            for element in history {
                continuation.yield(element)
            }
            switch terminal {
            case .success:
                continuation.finish()
            case .failure(let error):
                continuation.finish(throwing: error)
            case nil:
                continuations[id] = continuation
                continuation.onTermination = { [weak self] _ in
                    guard let self else { return }
                    Task { await self.unsubscribe(id) }
                }
            }
        }
    }

    private func unsubscribe(_ id: Int) {
        continuations.removeValue(forKey: id)
    }
}
