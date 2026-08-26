import Anthropic

/// Ported from `types/beta/beta_file_scope.py`. Not present on GA's `FileMetadata`.
public struct BetaFileScope: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
}

/// Ported from `types/beta/beta_file_metadata.py`. Diverges from GA's `FileMetadata` in both
/// directions -- it adds `scope` but drops `expiresAt` -- so this duplicates the type rather than
/// reusing `FileMetadata`.
public struct BetaFileMetadata: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int
    public let type: String
    public let downloadable: Bool?
    public let scope: BetaFileScope?
}

/// `types/beta/beta_deleted_file.py` is field-identical to GA's `DeletedFile`.
public typealias BetaDeletedFile = DeletedFile
