import Anthropic

/// Exposed as `client.beta.userProfiles`, mirroring `resources/beta/user_profiles.py`. Every
/// method sends `betaQuery` and merges in the mandatory `user-profiles-2026-08-18` beta header via
/// `betaRequestOptions`. There is no `delete` -- a profile can only be created, updated, retrieved,
/// or listed.
public struct BetaUserProfiles: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "user-profiles-2026-08-18"

    /// Create a user profile. Every field of `params` is optional, so this can be called with no
    /// arguments at all.
    public func create(
        _ params: BetaUserProfileCreateParams = BetaUserProfileCreateParams(),
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaUserProfile {
        try await client.transport.send(
            method: "POST",
            path: "v1/user_profiles",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a user profile by ID.
    public func retrieve(
        _ userProfileId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaUserProfile {
        try await client.transport.get(
            path: "v1/user_profiles/\(userProfileId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a user profile. Every field in `params` is a PATCH-merge -- see
    /// `BetaUserProfileUpdateParams` for the omit/preserve/clear semantics of each field.
    public func update(
        _ userProfileId: String,
        _ params: BetaUserProfileUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaUserProfile {
        try await client.transport.send(
            method: "POST",
            path: "v1/user_profiles/\(userProfileId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List user profiles, most recently created first. `order` is a flat `String?` (`"asc"` /
    /// `"desc"`), matching the codebase-wide rule that query-string filters stay flat even where a
    /// dedicated response enum exists for a similarly-named field.
    public func list(
        limit: Int? = nil,
        order: String? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaUserProfile> {
        try await client.transport.get(
            path: "v1/user_profiles",
            query: betaQuery.merging(
                [
                    "limit": limit.map(String.init),
                    "order": order,
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Create an enrollment URL for a user profile, to send to the end user. Valid until the
    /// returned `expiresAt`.
    public func createEnrollmentUrl(
        _ userProfileId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaUserProfileEnrollmentURL {
        try await client.transport.post(
            path: "v1/user_profiles/\(userProfileId.asPathComponent)/enrollment_url",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var userProfiles: BetaUserProfiles { BetaUserProfiles(client: client) }
}
