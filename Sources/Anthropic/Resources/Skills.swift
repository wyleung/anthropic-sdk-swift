import Foundation

/// A file to upload as part of a Skill or Skill Version. The reference SDKs accept a generic
/// `FileTypes` value (raw bytes, a path, or an explicit `(filename, content, contentType)` tuple)
/// for each entry in `files`; this port requires the explicit triple since Swift has no equivalent
/// of Python's open-file/bytes union.
public struct SkillFileUpload: Sendable {
    public let filename: String
    public let contentType: String
    public let data: Data

    public init(filename: String, contentType: String, data: Data) {
        self.filename = filename
        self.contentType = contentType
        self.data = data
    }
}

public struct Skills: Sendable {
    unowned let client: AnthropicClient

    /// All `files` must share the same top-level directory and include a `SKILL.md` at its root.
    public func create(
        files: [SkillFileUpload],
        displayName: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> Skill {
        var multipart = MultipartFormData()
        for file in files {
            multipart.addFile(name: "files", filename: file.filename, contentType: file.contentType, data: file.data)
        }
        if let displayName {
            multipart.addField(name: "display_name", value: displayName)
        }
        return try await client.transport.postMultipart(path: "v1/skills", multipart: multipart, options: options)
    }

    public func retrieve(_ skillId: String, options: RequestOptions = RequestOptions()) async throws -> Skill {
        try await client.transport.get(path: "v1/skills/\(skillId.asPathComponent)", options: options)
    }

    public func list(
        limit: Int? = nil,
        page: String? = nil,
        source: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<Skill> {
        try await client.transport.get(
            path: "v1/skills",
            query: ["limit": limit.map(String.init), "page": page, "source": source],
            options: options
        )
    }

    public func delete(_ skillId: String, options: RequestOptions = RequestOptions()) async throws -> DeletedSkill {
        try await client.transport.delete(path: "v1/skills/\(skillId.asPathComponent)", options: options)
    }
}

/// Exposed as `client.skills.versions`, mirroring the reference SDKs nesting this resource under
/// `skills/versions.py`.
public struct SkillVersions: Sendable {
    unowned let client: AnthropicClient

    /// All `files` must share the same top-level directory and include a `SKILL.md` at its root.
    public func create(
        skillId: String,
        files: [SkillFileUpload],
        options: RequestOptions = RequestOptions()
    ) async throws -> SkillVersion {
        var multipart = MultipartFormData()
        for file in files {
            multipart.addFile(name: "files", filename: file.filename, contentType: file.contentType, data: file.data)
        }
        return try await client.transport.postMultipart(
            path: "v1/skills/\(skillId.asPathComponent)/versions", multipart: multipart, options: options
        )
    }

    /// - Parameter version: A version ID, or `"latest"` for the skill's most recent version.
    public func retrieve(
        _ version: String,
        skillId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> SkillVersion {
        try await client.transport.get(path: "v1/skills/\(skillId.asPathComponent)/versions/\(version.asPathComponent)", options: options)
    }

    public func list(
        skillId: String,
        limit: Int? = nil,
        page: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<SkillVersion> {
        try await client.transport.get(
            path: "v1/skills/\(skillId.asPathComponent)/versions",
            query: ["limit": limit.map(String.init), "page": page],
            options: options
        )
    }

    /// - Parameter version: A version ID, or `"latest"` for the skill's most recent version.
    public func delete(
        _ version: String,
        skillId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> DeletedSkillVersion {
        try await client.transport.delete(path: "v1/skills/\(skillId.asPathComponent)/versions/\(version.asPathComponent)", options: options)
    }
}

extension Skills {
    public var versions: SkillVersions { SkillVersions(client: client) }
}
