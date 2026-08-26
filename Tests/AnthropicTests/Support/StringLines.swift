/// A trivial `Sendable` `AsyncSequence` over a fixed array of lines, standing in for
/// `URLSession.AsyncBytes.lines` in tests that exercise `sseEvents(from:)` without any real
/// networking.
struct StringLines: AsyncSequence, Sendable {
    typealias Element = String

    let lines: [String]

    struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: IndexingIterator<[String]>
        mutating func next() async -> String? { iterator.next() }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: lines.makeIterator())
    }
}
