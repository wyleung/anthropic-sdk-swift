import Anthropic

/// Exposed as `client.beta.agents`, mirroring `resources/beta/agents/agents.py`. Every method
/// sends `betaQuery` and merges in the mandatory `managed-agents-2026-04-01` beta header via
/// `betaRequestOptions`. Unlike `BetaEnvironments`, there is no `delete` endpoint here -- confirmed
/// absent from the Python resource file; `archive` is the only way to retire an agent.
public struct BetaAgents: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Create a new agent.
    public func create(
        _ params: BetaAgentCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsAgent {
        try await client.transport.send(
            method: "POST",
            path: "v1/agents",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve an agent by ID. Pass `version` to fetch a specific historical version; omit for
    /// the most recent version.
    public func retrieve(
        _ agentId: String,
        version: Int? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsAgent {
        try await client.transport.get(
            path: "v1/agents/\(agentId.asPathComponent)",
            query: betaQuery.merging(["version": version.map(String.init)]) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update an agent. Every field in `params` is a PATCH-merge -- see `BetaAgentUpdateParams`
    /// for the omit/null/value semantics of each field.
    public func update(
        _ agentId: String,
        _ params: BetaAgentUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsAgent {
        try await client.transport.send(
            method: "POST",
            path: "v1/agents/\(agentId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List agents, most recently created first. `createdAtGte`/`createdAtLte` are pre-formatted
    /// ISO8601 timestamp strings, sent as the literal `created_at[gte]`/`created_at[lte]` query
    /// keys (matching `agent_list_params.py`'s `PropertyInfo(alias=...)` aliases).
    public func list(
        createdAtGte: String? = nil,
        createdAtLte: String? = nil,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsAgent> {
        try await client.transport.get(
            path: "v1/agents",
            query: betaQuery.merging(
                [
                    "created_at[gte]": createdAtGte,
                    "created_at[lte]": createdAtLte,
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive an agent.
    public func archive(
        _ agentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsAgent {
        try await client.transport.post(
            path: "v1/agents/\(agentId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var agents: BetaAgents { BetaAgents(client: client) }
}
