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
        part.append(contentsOf: "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8)
        part.append(contentsOf: value.utf8)
        part.append(contentsOf: "\r\n".utf8)
        parts.append(part)
    }

    package mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        var part = Data()
        part.append(contentsOf: "--\(boundary)\r\n".utf8)
        part.append(
            contentsOf: "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8
        )
        part.append(contentsOf: "Content-Type: \(contentType)\r\n\r\n".utf8)
        part.append(data)
        part.append(contentsOf: "\r\n".utf8)
        parts.append(part)
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
