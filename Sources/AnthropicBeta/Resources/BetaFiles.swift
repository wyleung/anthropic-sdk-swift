import Anthropic
import Foundation

/// Every method sends the mandatory `"files-api-2025-04-14"` beta flag (see `betaRequestOptions`),
/// matching `beta/files.py`. Unlike GA's `Files.list` (`ids`/`limit`/`page` + `PageCursor`), Beta's
/// list is an id-cursor endpoint (`after_id`/`before_id`/`limit`/`scope_id` + `Page`) -- a genuine
/// divergence from GA confirmed by reading the Python source, not an oversight.
public struct BetaFiles: Sendable {
    unowned let client: AnthropicClient

    public func list(
        afterId: String? = nil,
        beforeId: String? = nil,
        limit: Int? = nil,
        scopeId: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<BetaFileMetadata> {
        try await client.transport.get(
            path: "v1/files",
            query: betaQuery.merging(
                [
                    "after_id": afterId,
                    "before_id": beforeId,
                    "limit": limit.map(String.init),
                    "scope_id": scopeId,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: "files-api-2025-04-14", base: options)
        )
    }

    public func delete(
        _ fileId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaDeletedFile {
        try await client.transport.delete(
            path: "v1/files/\(fileId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "files-api-2025-04-14", base: options)
        )
    }

    /// Returns the raw file bytes, matching GA's `Files.download` stance of not modeling a
    /// dedicated streaming-binary-response type.
    public func download(
        _ fileId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> Data {
        try await client.transport.getData(
            path: "v1/files/\(fileId)/content",
            query: betaQuery,
            accept: "application/binary",
            options: betaRequestOptions(betas: betas, requiredBeta: "files-api-2025-04-14", base: options)
        )
    }

    public func retrieveMetadata(
        _ fileId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaFileMetadata {
        try await client.transport.get(
            path: "v1/files/\(fileId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "files-api-2025-04-14", base: options)
        )
    }

    /// - Parameters:
    ///   - file: The raw bytes to upload.
    ///   - filename: Sent as the multipart part's `filename`.
    ///   - contentType: Sent as the multipart part's `Content-Type`.
    ///
    /// Unlike GA's `Files.upload`, Beta's upload has no `expiresInSeconds` param -- confirmed by
    /// reading `beta/files.py`, whose `upload` only accepts `file`.
    public func upload(
        file: Data,
        filename: String,
        contentType: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaFileMetadata {
        var multipart = MultipartFormData()
        multipart.addFile(name: "file", filename: filename, contentType: contentType, data: file)
        return try await client.transport.postMultipart(
            path: "v1/files",
            query: betaQuery,
            multipart: multipart,
            options: betaRequestOptions(betas: betas, requiredBeta: "files-api-2025-04-14", base: options)
        )
    }
}
