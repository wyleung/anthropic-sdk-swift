import Foundation

/// `URLProtocol` delivers the request body via `httpBodyStream`, not `httpBody`, once a request
/// has passed through `URLSession` -- even for the non-streaming `data(for:)` path. Shared by any
/// test that needs to assert on a request's serialized body (JSON or multipart).
func bodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: buffer.count)
        guard bytesRead > 0 else { break }
        data.append(buffer, count: bytesRead)
    }
    return data
}
