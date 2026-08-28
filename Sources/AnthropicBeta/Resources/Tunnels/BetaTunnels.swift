import Anthropic

/// Exposed as `client.beta.tunnels`, mirroring `resources/beta/tunnels/tunnels.py`. Every method
/// sends `betaQuery` and merges in the mandatory `mcp-tunnels-2026-06-22` beta header via
/// `betaRequestOptions`. `certificates` is exposed as a nested resource on `BetaTunnels` itself,
/// via the accessor in `BetaTunnelCertificates.swift`.
///
/// The Tunnels API is in research preview and may change without a deprecation period. It
/// supersedes the Admin API endpoints at `/v1/organizations/tunnels`, which remain available
/// during a migration window.
public struct BetaTunnels: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "mcp-tunnels-2026-06-22"

    /// Create a tunnel. Creation allocates a fresh hostname and provisions the tunnel; it is not
    /// idempotent. The new tunnel rejects MCP traffic until at least one CA certificate is added.
    public func create(
        _ params: BetaTunnelCreateParams = BetaTunnelCreateParams(),
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnel {
        try await client.transport.send(
            method: "POST",
            path: "v1/tunnels",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a tunnel by ID.
    public func retrieve(
        _ tunnelId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnel {
        try await client.transport.get(
            path: "v1/tunnels/\(tunnelId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List tunnels, most recently created first. Archived tunnels are excluded unless
    /// `includeArchived` is set.
    public func list(
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaTunnel> {
        try await client.transport.get(
            path: "v1/tunnels",
            query: betaQuery.merging(
                [
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a tunnel. Irreversible: every non-archived certificate on the tunnel is archived in
    /// the same operation, the hostname is retired and never re-allocated, and the tunnel token is
    /// invalidated. Retrying against an already-archived tunnel returns the existing record
    /// unchanged (idempotent on retry).
    public func archive(
        _ tunnelId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnel {
        try await client.transport.post(
            path: "v1/tunnels/\(tunnelId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Reveal a tunnel's connector token. The value is fetched live on every call -- Anthropic does
    /// not store it -- and repeated calls return the same value until rotated. Exposed as POST
    /// (not GET) so the token doesn't end up in intermediary access logs.
    public func revealToken(
        _ tunnelId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnelToken {
        try await client.transport.post(
            path: "v1/tunnels/\(tunnelId.asPathComponent)/reveal_token",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Rotate a tunnel's connector token. Rotation invalidates the current token for new
    /// connections and returns a fresh value; established connections are not severed. A connector
    /// restarted after rotation must use the new value.
    public func rotateToken(
        _ tunnelId: String,
        _ params: BetaTunnelRotateTokenParams = BetaTunnelRotateTokenParams(),
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnelToken {
        try await client.transport.send(
            method: "POST",
            path: "v1/tunnels/\(tunnelId.asPathComponent)/rotate_token",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var tunnels: BetaTunnels { BetaTunnels(client: client) }
}
