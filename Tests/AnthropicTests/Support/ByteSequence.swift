/// A trivial `Sendable` `AsyncSequence` over a fixed byte buffer, standing in for
/// `URLSession.AsyncBytes` in tests that exercise `sseLines(from:)` without any real networking.
struct ByteSequence: AsyncSequence, Sendable {
    typealias Element = UInt8

    let bytes: [UInt8]

    init(_ string: String) {
        self.bytes = Array(string.utf8)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: IndexingIterator<[UInt8]>
        mutating func next() async -> UInt8? { iterator.next() }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: bytes.makeIterator())
    }
}
