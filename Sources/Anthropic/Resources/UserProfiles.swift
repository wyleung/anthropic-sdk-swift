import Foundation

/// User Profiles, generally available as `client.userProfiles` -- the same resource `client.beta.userProfiles`
/// exposes with a legacy beta header, but returning the current shapes (enforcement status and actions,
/// programs, external user details). A profile's `id` can be sent as `anthropic-user-profile-id` on Messages,
/// Message Batches and token-counting requests to attribute usage to it.
public struct UserProfiles: Sendable {
    unowned let client: AnthropicClient

    public func create(
        _ params: UserProfileCreateParams = UserProfileCreateParams(),
        options: RequestOptions = RequestOptions()
    ) async throws -> UserProfile {
        try await client.transport.send(method: "POST", path: "v1/user_profiles", body: params, options: options)
    }

    public func retrieve(_ userProfileId: String, options: RequestOptions = RequestOptions()) async throws -> UserProfile {
        try await client.transport.get(path: "v1/user_profiles/\(userProfileId.asPathComponent)", options: options)
    }

    public func update(
        _ userProfileId: String,
        _ params: UserProfileUpdateParams,
        options: RequestOptions = RequestOptions()
    ) async throws -> UserProfile {
        try await client.transport.send(
            method: "POST", path: "v1/user_profiles/\(userProfileId.asPathComponent)", body: params, options: options
        )
    }

    /// - Parameters:
    ///   - enforcementStatus: Return only profiles whose `enforcementStatus` is one of these (`"unrestricted"`,
    ///     `"pending"`, `"restricted"`, `"banned"`). With it set, a page may hold fewer than `limit` profiles --
    ///     or none -- and still carry a `nextPage`: the service examines a bounded number of profiles per page.
    ///   - order: `"asc"` or `"desc"`.
    ///   - orderBy: `"created_at"` (the default) or `"name"`.
    public func list(
        enforcementStatus: [String]? = nil,
        limit: Int? = nil,
        order: String? = nil,
        orderBy: String? = nil,
        page: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<UserProfile> {
        try await client.transport.get(
            path: "v1/user_profiles",
            query: ["limit": limit.map(String.init), "order": order, "order_by": orderBy, "page": page],
            arrayQuery: ["enforcement_status": enforcementStatus],
            options: options
        )
    }

    public func delete(_ userProfileId: String, options: RequestOptions = RequestOptions()) async throws -> DeletedUserProfile {
        try await client.transport.delete(path: "v1/user_profiles/\(userProfileId.asPathComponent)", options: options)
    }

    public var actionURLs: UserProfileActionURLs { UserProfileActionURLs(client: client) }
}

/// Exposed as `client.userProfiles.actionURLs`.
public struct UserProfileActionURLs: Sendable {
    unowned let client: AnthropicClient

    /// Creates a one-time URL for an action the end user must take; today the only action is enrolling.
    public func create(
        _ userProfileId: String,
        action: UserProfileEnrollEndUserActionParam = UserProfileEnrollEndUserActionParam(),
        options: RequestOptions = RequestOptions()
    ) async throws -> UserProfileActionURL {
        try await client.transport.send(
            method: "POST",
            path: "v1/user_profiles/\(userProfileId.asPathComponent)/action_urls",
            body: UserProfileActionURLCreateParams(action: action),
            options: options
        )
    }
}
