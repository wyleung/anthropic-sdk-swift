import Anthropic

/// Exposed as `client.beta.agents.versions`, mirroring `resources/beta/agents/versions.py`.
public struct BetaAgentVersions: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// List every version of an agent, most recent first.
    public func list(
        agentId: String,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsAgent> {
        try await client.transport.get(
            path: "v1/agents/\(agentId.asPathComponent)/versions",
            query: betaQuery.merging(
                [
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension BetaAgents {
    public var versions: BetaAgentVersions { BetaAgentVersions(client: client) }
}
