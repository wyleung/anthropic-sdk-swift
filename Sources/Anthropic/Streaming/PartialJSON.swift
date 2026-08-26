/// A hand-written lenient JSON parser tolerant of truncated input, used to render a live
/// snapshot of a tool call's `input` while its `input_json_delta` fragments are still arriving.
/// Mirrors the Python SDK's `jiter.from_json(buffer, partial_mode=True)`: the buffer is always a
/// prefix of some well-formed JSON document (the server never emits genuinely malformed JSON),
/// so this does not attempt to be a general-purpose fault-tolerant parser -- it only needs to
/// resolve *incompleteness*, not invalid syntax.
///
/// Policy, matching jiter's partial mode: a truncated trailing **string value** is kept as-is (so
/// a streamed string argument renders character-by-character); any other truncated trailing
/// token -- a partial key, number, literal, or an in-progress nested container's last element --
/// is dropped, since a half-typed key or number isn't a meaningful value to show.
enum PartialJSON {
    static func parse(_ text: String) throws -> JSONValue {
        var scanner = JSONScanner(text)
        do {
            return try scanner.parseValue()
        } catch {
            throw AnthropicError.responseValidation(
                message: "Unable to parse tool parameter JSON from model. Please file an issue.",
                body: nil
            )
        }
    }
}

/// Thrown internally while scanning; never escapes `PartialJSON.parse`.
private enum ScanError: Error {
    /// Input ended before the current token could be completed.
    case truncated
    /// The input isn't a valid prefix of well-formed JSON.
    case malformed(String)
}

private extension Character {
    var isASCIIDigit: Bool { self >= "0" && self <= "9" }
}

private struct JSONScanner {
    let text: String
    var index: String.Index

    init(_ text: String) {
        self.text = text
        self.index = text.startIndex
    }

    var isAtEnd: Bool { index >= text.endIndex }

    func peek() -> Character? {
        isAtEnd ? nil : text[index]
    }

    @discardableResult
    mutating func advance() -> Character? {
        guard !isAtEnd else { return nil }
        let c = text[index]
        index = text.index(after: index)
        return c
    }

    mutating func skipWhitespace() {
        while let c = peek(), c == " " || c == "\t" || c == "\n" || c == "\r" {
            advance()
        }
    }

    mutating func consume(_ expected: Character) -> Bool {
        guard peek() == expected else { return false }
        advance()
        return true
    }

    mutating func parseValue() throws -> JSONValue {
        skipWhitespace()
        guard let c = peek() else { throw ScanError.truncated }
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"":
            let (value, _) = try parseStringBody(lenientTrailing: true)
            return .string(value)
        case "t", "f", "n": return try parseLiteral()
        default: return try parseNumber()
        }
    }

    mutating func parseObject() throws -> JSONValue {
        guard consume("{") else { throw ScanError.malformed("expected {") }
        var members: [String: JSONValue] = [:]
        skipWhitespace()
        if consume("}") { return .object(members) }
        while true {
            skipWhitespace()
            guard peek() == "\"" else {
                if isAtEnd { return .object(members) }
                throw ScanError.malformed("expected string key in object")
            }
            let memberStart = index
            do {
                let (key, _) = try parseStringBody(lenientTrailing: false)
                skipWhitespace()
                guard consume(":") else {
                    if isAtEnd {
                        index = memberStart
                        return .object(members)
                    }
                    throw ScanError.malformed("expected : in object")
                }
                skipWhitespace()
                guard !isAtEnd else {
                    index = memberStart
                    return .object(members)
                }
                members[key] = try parseValue()
            } catch ScanError.truncated {
                index = memberStart
                return .object(members)
            }

            skipWhitespace()
            if consume(",") {
                skipWhitespace()
                if isAtEnd { return .object(members) }
                continue
            }
            if consume("}") { return .object(members) }
            if isAtEnd { return .object(members) }
            throw ScanError.malformed("expected , or } in object")
        }
    }

    mutating func parseArray() throws -> JSONValue {
        guard consume("[") else { throw ScanError.malformed("expected [") }
        var elements: [JSONValue] = []
        skipWhitespace()
        if consume("]") { return .array(elements) }
        while true {
            skipWhitespace()
            guard !isAtEnd else { return .array(elements) }
            let elementStart = index
            do {
                elements.append(try parseValue())
            } catch ScanError.truncated {
                index = elementStart
                return .array(elements)
            }

            skipWhitespace()
            if consume(",") {
                skipWhitespace()
                if isAtEnd { return .array(elements) }
                continue
            }
            if consume("]") { return .array(elements) }
            if isAtEnd { return .array(elements) }
            throw ScanError.malformed("expected , or ] in array")
        }
    }

    /// `lenientTrailing: false` (object keys) throws `.truncated` on an unterminated string.
    /// `lenientTrailing: true` (values) never throws for truncation -- it returns the partial
    /// content parsed so far, which can only happen when the string is the very last token
    /// physically present in the buffer.
    mutating func parseStringBody(lenientTrailing: Bool) throws -> (value: String, complete: Bool) {
        guard consume("\"") else { throw ScanError.malformed("expected string") }
        var result = ""
        while let c = peek() {
            if c == "\"" {
                advance()
                return (result, true)
            }
            if c == "\\" {
                advance()
                guard let escaped = peek() else {
                    if lenientTrailing { return (result, false) }
                    throw ScanError.truncated
                }
                advance()
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "u":
                    guard let scalar = try parseUnicodeEscape(lenientTrailing: lenientTrailing) else {
                        return (result, false)
                    }
                    result.unicodeScalars.append(scalar)
                default:
                    throw ScanError.malformed("invalid escape")
                }
                continue
            }
            result.append(c)
            advance()
        }
        if lenientTrailing { return (result, false) }
        throw ScanError.truncated
    }

    /// Returns `nil` (meaning: leniently truncated, drop this escape) only when `lenientTrailing`
    /// and input ends mid-escape; otherwise returns the decoded scalar, combining a surrogate
    /// pair (`😀`-style) into one scalar when present.
    mutating func parseUnicodeEscape(lenientTrailing: Bool) throws -> Unicode.Scalar? {
        guard let high = try readHex4(lenientTrailing: lenientTrailing) else { return nil }
        if (0xD800...0xDBFF).contains(high) {
            guard peek() == "\\" else {
                if lenientTrailing, isAtEnd { return nil }
                throw ScanError.malformed("unpaired surrogate")
            }
            let backslashIndex = index
            advance()
            guard consume("u") else {
                if lenientTrailing, isAtEnd {
                    index = backslashIndex
                    return nil
                }
                throw ScanError.malformed("expected low surrogate escape")
            }
            guard let low = try readHex4(lenientTrailing: lenientTrailing) else { return nil }
            guard (0xDC00...0xDFFF).contains(low) else {
                throw ScanError.malformed("invalid low surrogate")
            }
            let combined = 0x10000 + (high - 0xD800) * 0x400 + (low - 0xDC00)
            return Unicode.Scalar(combined)
        }
        return Unicode.Scalar(high)
    }

    mutating func readHex4(lenientTrailing: Bool) throws -> UInt32? {
        var hex = ""
        for _ in 0..<4 {
            guard let h = advance() else {
                if lenientTrailing { return nil }
                throw ScanError.truncated
            }
            hex.append(h)
        }
        guard let value = UInt32(hex, radix: 16) else {
            throw ScanError.malformed("invalid hex escape")
        }
        return value
    }

    private enum LiteralMatch { case matched, mismatch, truncated }

    mutating func parseLiteral() throws -> JSONValue {
        switch matchLiteral("true") {
        case .matched: return .bool(true)
        case .truncated: throw ScanError.truncated
        case .mismatch: break
        }
        switch matchLiteral("false") {
        case .matched: return .bool(false)
        case .truncated: throw ScanError.truncated
        case .mismatch: break
        }
        switch matchLiteral("null") {
        case .matched: return .null
        case .truncated: throw ScanError.truncated
        case .mismatch: break
        }
        throw ScanError.malformed("invalid literal")
    }

    private mutating func matchLiteral(_ literal: String) -> LiteralMatch {
        let saved = index
        for expected in literal {
            guard let c = advance() else {
                index = saved
                return .truncated
            }
            guard c == expected else {
                index = saved
                return .mismatch
            }
        }
        return .matched
    }

    mutating func parseNumber() throws -> JSONValue {
        let start = index
        if peek() == "-" { advance() }
        guard let first = peek(), first.isASCIIDigit else {
            index = start
            throw ScanError.malformed("invalid number")
        }
        consumeDigits()
        if peek() == "." {
            let dotIndex = index
            advance()
            if let afterDot = peek(), afterDot.isASCIIDigit {
                consumeDigits()
            } else {
                index = dotIndex
            }
        }
        if peek() == "e" || peek() == "E" {
            let eIndex = index
            advance()
            if peek() == "+" || peek() == "-" { advance() }
            if let afterExp = peek(), afterExp.isASCIIDigit {
                consumeDigits()
            } else {
                index = eIndex
            }
        }
        // A number has no closing delimiter of its own, so if the buffer ends right after its
        // last digit there's no way to tell whether more digits are still arriving. Matching
        // jiter's non-string partial policy, treat that ambiguity as truncated and drop it --
        // only strings get trailing leniency.
        guard !isAtEnd else { throw ScanError.truncated }
        guard let value = Double(text[start..<index]) else {
            index = start
            throw ScanError.malformed("invalid number literal")
        }
        return .number(value)
    }

    mutating func consumeDigits() {
        while let c = peek(), c.isASCIIDigit { advance() }
    }
}
