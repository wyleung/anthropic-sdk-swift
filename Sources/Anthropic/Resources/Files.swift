import Foundation

public struct Files: Sendable {
    unowned let client: AnthropicClient

    /// `ids` is mutually exclusive with `page`/`limit` per the reference SDKs' docs: when
    /// supplied, the response is always a single page (`nextPage` is null).
    public func list(
        ids: [String]? = nil,
        limit: Int? = nil,
        page: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<FileMetadata> {
        try await client.transport.get(
            path: "v1/files",
            query: ["limit": limit.map(String.init), "page": page],
            arrayQuery: ["ids": ids],
            options: options
        )
    }

    public func delete(_ fileId: String, options: RequestOptions = RequestOptions()) async throws -> DeletedFile {
        try await client.transport.delete(path: "v1/files/\(fileId)", options: options)
    }

    /// Returns the raw file bytes. The reference SDKs expose a `BinaryAPIResponse` wrapper with
    /// header/streaming accessors; this port returns `Data` directly, matching `MessageBatches.results`'s
    /// stance of not yet modeling a dedicated streaming-binary-response type.
    public func download(_ fileId: String, options: RequestOptions = RequestOptions()) async throws -> Data {
        try await client.transport.getData(
            path: "v1/files/\(fileId)/content", accept: "application/binary", options: options
        )
    }

    public func retrieveMetadata(
        _ fileId: String, options: RequestOptions = RequestOptions()
    ) async throws -> FileMetadata {
        try await client.transport.get(path: "v1/files/\(fileId)", options: options)
    }

    /// - Parameters:
    ///   - file: The raw bytes to upload.
    ///   - filename: Sent as the multipart part's `filename`.
    ///   - contentType: Sent as the multipart part's `Content-Type`.
    ///   - expiresInSeconds: Must be between 3600 (one hour) and 7776000 (ninety days) if supplied.
    public func upload(
        file: Data,
        filename: String,
        contentType: String,
        expiresInSeconds: Int? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> FileMetadata {
        var multipart = MultipartFormData()
        multipart.addFile(name: "file", filename: filename, contentType: contentType, data: file)
        if let expiresInSeconds {
            multipart.addField(name: "expires_in_seconds", value: String(expiresInSeconds))
        }
        return try await client.transport.postMultipart(path: "v1/files", multipart: multipart, options: options)
    }
}
