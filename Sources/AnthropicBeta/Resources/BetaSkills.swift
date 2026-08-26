import Anthropic
import Foundation

/// Every method sends the mandatory `"skills-2025-10-02"` beta flag (see `betaRequestOptions`),
/// matching `beta/skills/skills.py`. Reuses GA's `SkillFileUpload` directly for `files` -- it's
/// just filename/contentType/data, with no Beta-specific fields.
public struct BetaSkills: Sendable {
    unowned let client: AnthropicClient

    /// All `files` must share the same top-level directory and include a `SKILL.md` at its root.
    public func create(
        files: [SkillFileUpload],
        displayTitle: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaSkillSummary {
        var multipart = MultipartFormData()
        for file in files {
            multipart.addFile(name: "files", filename: file.filename, contentType: file.contentType, data: file.data)
        }
        if let displayTitle {
            multipart.addField(name: "display_title", value: displayTitle)
        }
        return try await client.transport.postMultipart(
            path: "v1/skills",
            query: betaQuery,
            multipart: multipart,
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
        )
    }

    public func retrieve(
        _ skillId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaSkillSummary {
        try await client.transport.get(
            path: "v1/skills/\(skillId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
        )
    }

    public func list(
        limit: Int? = nil,
        page: String? = nil,
        source: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaSkillSummary> {
        try await client.transport.get(
            path: "v1/skills",
            query: betaQuery.merging(
                ["limit": limit.map(String.init), "page": page, "source": source]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
        )
    }

    public func delete(
        _ skillId: String, betas: [String] = [], options: RequestOptions = RequestOptions()
    ) async throws -> BetaDeletedSkill {
        try await client.transport.delete(
            path: "v1/skills/\(skillId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
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
            path: "v1/skills/\(skillId)/versions",
            query: betaQuery,
            multipart: multipart,
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
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
            path: "v1/skills/\(skillId)/versions/\(version)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
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
            path: "v1/skills/\(skillId)/versions",
            query: betaQuery.merging(["limit": limit.map(String.init), "page": page]) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
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
            path: "v1/skills/\(skillId)/versions/\(version)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "skills-2025-10-02", base: options)
        )
    }
}

extension BetaSkills {
    public var versions: BetaSkillVersions { BetaSkillVersions(client: client) }
}
