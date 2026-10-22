import Anthropic

/// Ported from `types/beta/beta_file_scope.py`. Not present on GA's `FileMetadata`.
public struct BetaFileScope: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
}

/// Ported from `types/beta/beta_file_metadata.py`: GA's `FileMetadata` plus `scope`, so this duplicates
/// the type rather than reusing it. (It used to also drop `expiresAt`; upstream added it here when the
/// Beta Files namespace adopted the GA shapes.)
public struct BetaFileMetadata: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: String
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int
    public let type: String
    public let downloadable: Bool?
    /// When the file expires and is deleted; `nil` if it doesn't.
    public let expiresAt: String?
    public let scope: BetaFileScope?
}

/// `types/beta/beta_deleted_file.py` is field-identical to GA's `DeletedFile`.
public typealias BetaDeletedFile = DeletedFile
