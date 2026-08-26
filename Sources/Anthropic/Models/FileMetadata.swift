/// Ported from `types/file_metadata.py`. Date fields stay `String`, matching `Container.expiresAt`.
public struct FileMetadata: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int
    public let type: String
    public let downloadable: Bool?
    public let expiresAt: String?
}

/// Ported from `types/deleted_file.py`. `type` is optional here (unlike `DeletedMessageBatch`/
/// `DeletedSkill`), matching the Python source's `Optional[Literal["file_deleted"]] = None`.
public struct DeletedFile: Codable, Sendable, Equatable {
    public let id: String
    public let type: String?
}
