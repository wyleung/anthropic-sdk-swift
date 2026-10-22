import Anthropic
import Foundation

/// Sends `?beta=true` and, only when you pass `betas`, an `anthropic-beta` header -- matching
/// `beta/skills/skills.py`, which dropped the mandatory dated `skills-2025-10-02` pin. That header
/// selects the *legacy* response shapes, so without it these methods return GA's (`Skill`,
/// `SkillVersion`); a caller who still passes the header gets the legacy shapes back, which won't
/// decode as `BetaSkill`. Reuses GA's `SkillFileUpload` directly for `files`.
///
/// `delete` removes a skill together with all of its versions (it used to refuse while any existed).
public struct BetaSkills: Sendable {
    unowned let client: AnthropicClient

    /// All `files` must share the same top-level directory and include a `SKILL.md` at its root.
    public func create(
        files: [SkillFileUpload],
        displayName: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSkill {
        var multipart = MultipartFormData()
        for file in files {
            multipart.addFile(name: "files", filename: file.filename, contentType: file.contentType, data: file.data)
        }
        if let displayName {
            multipart.addField(name: "display_name", value: displayName)
        }
        return try await client.transport.postMultipart(
            path: "v1/skills",
            query: betaQuery,
            multipart: multipart,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    public func retrieve(
        _ skillId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaSkill {
        try await client.transport.get(
            path: "v1/skills/\(skillId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    public func list(
        limit: Int? = nil,
        page: String? = nil,
        source: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaSkill> {
        try await client.transport.get(
            path: "v1/skills",
            query: betaQuery.merging(
                ["limit": limit.map(String.init), "page": page, "source": source]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    public func delete(
        _ skillId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaDeletedSkill {
        try await client.transport.delete(
            path: "v1/skills/\(skillId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }
}

/// Exposed as `client.beta.skills.versions`, mirroring GA's `Skills.versions` nesting.
public struct BetaSkillVersions: Sendable {
    unowned let client: AnthropicClient

    /// All `files` must share the same top-level directory and include a `SKILL.md` at its root.
    public func create(
        skillId: String,
        files: [SkillFileUpload],
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSkillVersion {
        var multipart = MultipartFormData()
        for file in files {
            multipart.addFile(name: "files", filename: file.filename, contentType: file.contentType, data: file.data)
        }
        return try await client.transport.postMultipart(
            path: "v1/skills/\(skillId.asPathComponent)/versions",
            query: betaQuery,
            multipart: multipart,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    /// - Parameter version: A version ID, or `"latest"` for the skill's most recent version.
    public func retrieve(
        _ version: String,
        skillId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSkillVersion {
        try await client.transport.get(
            path: "v1/skills/\(skillId.asPathComponent)/versions/\(version.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    public func list(
        skillId: String,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaSkillVersion> {
        try await client.transport.get(
            path: "v1/skills/\(skillId.asPathComponent)/versions",
            query: betaQuery.merging(["limit": limit.map(String.init), "page": page]) { _, new in new },
            options: betaRequestOptions(betas: betas, base: options)
        )
    }

    /// - Parameter version: A version ID, or `"latest"` for the skill's most recent version.
    public func delete(
        _ version: String,
        skillId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaDeletedSkillVersion {
        try await client.transport.delete(
            path: "v1/skills/\(skillId.asPathComponent)/versions/\(version.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, base: options)
        )
    }
}

extension BetaSkills {
    public var versions: BetaSkillVersions { BetaSkillVersions(client: client) }
}
