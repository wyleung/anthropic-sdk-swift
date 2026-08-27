import Anthropic

/// Exposed as `client.beta.sessions.resources`, mirroring `resources/beta/sessions/resources.py`.
/// `retrieve`/`update` both return `BetaManagedAgentsSessionResource` -- Python's
/// `ResourceRetrieveResponse`/`ResourceUpdateResponse` are confirmed byte-identical unions to
/// `BetaManagedAgentsSessionResource` itself, so this port doesn't duplicate them as separate
/// types. `add`'s body reuses `BetaManagedAgentsFileResourceParams` directly -- Python's
/// `resource_add_params.py` is byte-identical to it (only a `file` resource can be added
/// after session creation).
public struct BetaSessionResources: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// A one-off body for `update`, which the reference SDK types as a bare
    /// `{authorization_token: str}` params object -- not worth a dedicated public params type for
    /// a single field.
    private struct UpdateBody: Encodable, Sendable {
        var authorizationToken: String
    }

    /// Retrieve a session resource by ID.
    public func retrieve(
        _ resourceId: String,
        sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSessionResource {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId)/resources/\(resourceId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Rotate the authorization token for a resource. Currently only `github_repository`
    /// resources support token rotation.
    public func update(
        _ resourceId: String,
        sessionId: String,
        authorizationToken: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsSessionResource {
        try await client.transport.send(
            method: "POST",
            path: "v1/sessions/\(sessionId)/resources/\(resourceId)",
            query: betaQuery,
            body: UpdateBody(authorizationToken: authorizationToken),
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List resources mounted into a session.
    public func list(
        sessionId: String,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsSessionResource> {
        try await client.transport.get(
            path: "v1/sessions/\(sessionId)/resources",
            query: betaQuery.merging(
                [
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Permanently remove a resource from a session.
    public func delete(
        _ resourceId: String,
        sessionId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeleteSessionResource {
        try await client.transport.delete(
            path: "v1/sessions/\(sessionId)/resources/\(resourceId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Mount a file into a running session's container.
    public func add(
        sessionId: String,
        _ params: BetaManagedAgentsFileResourceParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsFileResource {
        try await client.transport.send(
            method: "POST",
            path: "v1/sessions/\(sessionId)/resources",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaSessions {
    public var resources: BetaSessionResources { BetaSessionResources(client: client) }
}
