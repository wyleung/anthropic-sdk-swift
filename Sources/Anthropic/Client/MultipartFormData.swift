import Foundation

/// A `multipart/form-data` request body builder, used by the three upload endpoints
/// (`Files.upload`, `Skills.create`, `Skills.Versions.create`) that the reference SDKs send via
/// their HTTP library's multipart helpers -- Swift has no such helper on `URLSession`, so this
/// builds the boundary-delimited body by hand.
package struct MultipartFormData {
    private let boundary = "AnthropicSwiftBoundary-\(UUID().uuidString)"
    private var parts: [Data] = []

    package init() {}

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    package mutating func addField(name: String, value: String) {
        var part = Data()
        part.append(contentsOf: "--\(boundary)\r\n".utf8)
        part.append(contentsOf: "Content-Disposition: form-data; name=\"\(Self.escape(name))\"\r\n\r\n".utf8)
        part.append(contentsOf: value.utf8)
        part.append(contentsOf: "\r\n".utf8)
        parts.append(part)
    }

    package mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        var part = Data()
        part.append(contentsOf: "--\(boundary)\r\n".utf8)
        part.append(
            contentsOf: """
            Content-Disposition: form-data; name="\(Self.escape(name))"; filename="\(Self.escape(filename))"\r\n
            """.utf8
        )
        part.append(contentsOf: "Content-Type: \(contentType)\r\n\r\n".utf8)
        part.append(data)
        part.append(contentsOf: "\r\n".utf8)
        parts.append(part)
    }

    /// Escapes a `name`/`filename` for safe use inside a quoted `Content-Disposition` header value:
    /// `"` is backslash-escaped (matching the reference SDKs' quoting behavior) and CR/LF are
    /// stripped outright, since a raw newline would let a caller-supplied filename inject an
    /// arbitrary extra header or part boundary into the multipart body.
    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    func encode() -> Data {
        var body = Data()
        for part in parts {
            body.append(part)
        }
        body.append(contentsOf: "--\(boundary)--\r\n".utf8)
        return body
    }
}
