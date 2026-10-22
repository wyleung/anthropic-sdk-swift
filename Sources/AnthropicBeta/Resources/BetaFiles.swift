import Anthropic
import Foundation

/// Sends `?beta=true` and, only when you pass `betas`, an `anthropic-beta` header -- matching
/// `beta/files.py`, which dropped the mandatory dated `files-api-2025-04-14` pin. That header selects the
/// *legacy* response shapes (an id-cursor list with `has_more`/`first_id`/`last_id`); without it the
/// endpoints behave like GA's, so `list` now pages with `ids`/`page` and returns a `PageCursor`. A caller
/// who still passes the legacy header gets the legacy shapes back, which won't decode as `PageCursor`.
public struct BetaFiles: Sendable {
    unowned let client: AnthropicClient

    /// `ids` is mutually exclusive with `page`/`limit`: when supplied, the response is always a single
    /// page (`nextPage` is `nil`).
    public func list(
        ids: [String]? = nil,
        limit: Int? = nil,
        page: String? = nil,
        scopeId: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaFileMetadata> {
        try await client.transport.get(
            path: "v1/files",
            query: betaQuery.merging(
                ["limit": limit.map(String.init), "page": page, "scope_id": scopeId]
            ) { _, new in new },
            arrayQuery: ["ids": ids],
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    public func delete(
        _ fileId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaDeletedFile {
        try await client.transport.delete(
            path: "v1/files/\(fileId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    /// Returns the raw file bytes, matching GA's `Files.download` stance of not modeling a
    /// dedicated streaming-binary-response type.
    public func download(
        _ fileId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> Data {
        try await client.transport.getData(
            path: "v1/files/\(fileId.asPathComponent)/content",
            query: betaQuery,
            accept: "application/binary",
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    public func retrieveMetadata(
        _ fileId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaFileMetadata {
        try await client.transport.get(
            path: "v1/files/\(fileId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    /// - Parameters:
    ///   - file: The raw bytes to upload.
    ///   - filename: Sent as the multipart part's `filename`.
    ///   - contentType: Sent as the multipart part's `Content-Type`.
    ///   - expiresInSeconds: How long until the file expires; sent as the `expires_in_seconds` form field.
    public func upload(
        file: Data,
        filename: String,
        contentType: String,
        expiresInSeconds: Int? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaFileMetadata {
        var multipart = MultipartFormData()
        multipart.addFile(name: "file", filename: filename, contentType: contentType, data: file)
        if let expiresInSeconds {
            multipart.addField(name: "expires_in_seconds", value: String(expiresInSeconds))
        }
        return try await client.transport.postMultipart(
            path: "v1/files",
            query: betaQuery,
            multipart: multipart,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }
}
