/// One decoded SSE message: an optional `event:` name, the concatenation of its `data:` lines,
/// and the raw lines it was built from. Modeled after the TypeScript SDK's leaner shape rather
/// than Python's — neither reference's Messages-streaming consumer reads `id`/`retry`, so this
/// port omits them rather than porting SSE-spec fields nothing downstream uses.
public struct ServerSentEvent: Sendable, Equatable {
    public let event: String?
    public let data: String
    public let raw: [String]
}

/// A blank-line-delimited SSE decoder, ported from the reference SDKs' `SSEDecoder` classes.
/// Value-type state machine: feed it one already-newline-split line at a time via `decode(_:)`.
struct SSEDecoder {
    private var event: String?
    private var data: [String] = []
    private var raw: [String] = []

    mutating func decode(_ rawLine: String) -> ServerSentEvent? {
        var line = Substring(rawLine)
        if line.hasSuffix("\r") {
            line.removeLast()
        }

        if line.isEmpty {
            guard event != nil || !data.isEmpty else { return nil }
            let sse = ServerSentEvent(event: event, data: data.joined(separator: "\n"), raw: raw)
            event = nil
            data = []
            raw = []
            return sse
        }

        raw.append(String(line))

        if line.hasPrefix(":") {
            return nil
        }

        let (field, value) = Self.partition(line)
        if field == "event" {
            event = value
        } else if field == "data" {
            data.append(value)
        }
        return nil
    }

    /// Splits on the first `:` and strips a single leading space from the value, matching both
    /// references' field-parsing behavior.
    private static func partition(_ line: Substring) -> (field: String, value: String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return (String(line), "")
        }
        let field = line[line.startIndex..<colonIndex]
        var value = line[line.index(after: colonIndex)...]
        if value.hasPrefix(" ") {
            value.removeFirst()
        }
        return (String(field), String(value))
    }
}

/// Splits a raw byte stream into lines on `\n`, preserving blank lines.
///
/// Deliberately does not use Foundation's `AsyncLineSequence` (`URLSession.AsyncBytes.lines`,
/// `FileHandle.bytes.lines`): it silently coalesces away every empty line, on every tested
/// Foundation version. `SSEDecoder.decode` flushes an event precisely on a blank line, so feeding
/// it through `.lines` means it never sees one and never flushes -- zero events, always, for any
/// real network response. Splitting on `\n` ourselves is the fix.
func sseLines<Bytes: AsyncSequence>(from bytes: Bytes) -> AsyncThrowingStream<String, Error>
where Bytes.Element == UInt8, Bytes: Sendable {
    AsyncThrowingStream { continuation in
        let task = Task {
            var buffer: [UInt8] = []
            do {
                for try await byte in bytes {
                    if byte == UInt8(ascii: "\n") {
                        continuation.yield(String(decoding: buffer, as: UTF8.self))
                        buffer.removeAll(keepingCapacity: true)
                    } else {
                        buffer.append(byte)
                    }
                }
                if !buffer.isEmpty {
                    continuation.yield(String(decoding: buffer, as: UTF8.self))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// Wraps any line-yielding async sequence (production: `sseLines(from:)` over the raw response
/// bytes; tests: a synthetic sequence of fixture lines) into a sequence of decoded
/// `ServerSentEvent`s.
///
/// No artificial final flush is added at stream end: both reference SDKs only complete an SSE
/// event on a blank line, so a well-formed stream (which always ends its last event with one)
/// needs none, and diverging here would just be unjustified extra complexity.
func sseEvents<Lines: AsyncSequence>(from lines: Lines) -> AsyncThrowingStream<ServerSentEvent, Error>
where Lines.Element == String, Lines: Sendable {
    AsyncThrowingStream { continuation in
        let task = Task {
            var decoder = SSEDecoder()
            do {
                for try await line in lines {
                    if let event = decoder.decode(line) {
                        continuation.yield(event)
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
