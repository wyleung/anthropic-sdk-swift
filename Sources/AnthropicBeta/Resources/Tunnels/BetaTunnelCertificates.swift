import Anthropic

/// Exposed as `client.beta.tunnels.certificates`, mirroring
/// `resources/beta/tunnels/certificates.py`.
///
/// Python's own `retrieve`/`archive` put `certificate_id` first positionally despite `tunnel_id`
/// leading the URL path (`/v1/tunnels/{tunnel_id}/certificates/{certificate_id}`) -- a Python
/// positional-arg artifact. Following the labeled, parent-first convention already established by
/// `BetaEnvironmentWork` (`work.retrieve(environmentId:workId:)`), every method here takes
/// `tunnelId:` before `certificateId:`, matching the URL path.
public struct BetaTunnelCertificates: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "mcp-tunnels-2026-06-22"

    /// Register a public CA certificate on a tunnel. Anthropic verifies the gateway's server
    /// certificate against this CA when it terminates the inner TLS session. A tunnel holds at
    /// most two non-archived certificates.
    public func create(
        tunnelId: String,
        _ params: BetaCertificateCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnelCertificate {
        try await client.transport.send(
            method: "POST",
            path: "v1/tunnels/\(tunnelId)/certificates",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a tunnel certificate by ID.
    public func retrieve(
        tunnelId: String,
        certificateId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnelCertificate {
        try await client.transport.get(
            path: "v1/tunnels/\(tunnelId)/certificates/\(certificateId)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List the certificates registered on a tunnel. Archived certificates are excluded unless
    /// `includeArchived` is set.
    public func list(
        tunnelId: String,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaTunnelCertificate> {
        try await client.transport.get(
            path: "v1/tunnels/\(tunnelId)/certificates",
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

    /// Archive a tunnel certificate, removing it from the set Anthropic trusts for the tunnel. The
    /// certificate record is retained. Archiving the last non-archived certificate is permitted;
    /// the tunnel then rejects MCP traffic until a new certificate is added.
    public func archive(
        tunnelId: String,
        certificateId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaTunnelCertificate {
        try await client.transport.post(
            path: "v1/tunnels/\(tunnelId)/certificates/\(certificateId)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaTunnels {
    public var certificates: BetaTunnelCertificates { BetaTunnelCertificates(client: client) }
}
