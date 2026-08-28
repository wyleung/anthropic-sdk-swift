import Anthropic

/// Exposed as `client.beta.deployments`, mirroring `resources/beta/deployments.py`. Every method
/// sends `betaQuery` and merges in the mandatory `managed-agents-2026-04-01` beta header via
/// `betaRequestOptions`. `run` returns a `BetaManagedAgentsDeploymentRun`, not a
/// `BetaManagedAgentsDeployment` -- it's a one-off manual trigger, not a deployment mutation.
public struct BetaDeployments: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Create a deployment.
    public func create(
        _ params: BetaDeploymentCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeployment {
        try await client.transport.send(
            method: "POST",
            path: "v1/deployments",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve a deployment by ID.
    public func retrieve(
        _ deploymentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeployment {
        try await client.transport.get(
            path: "v1/deployments/\(deploymentId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update a deployment. Every field in `params` is a PATCH-merge -- see
    /// `BetaDeploymentUpdateParams` for the omit/preserve/clear semantics of each field.
    public func update(
        _ deploymentId: String,
        _ params: BetaDeploymentUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeployment {
        try await client.transport.send(
            method: "POST",
            path: "v1/deployments/\(deploymentId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List deployments, most recently created first. `createdAtGte`/`createdAtLte` are
    /// pre-formatted ISO8601 timestamp strings, sent as the literal `created_at[gte]`/
    /// `created_at[lte]` query keys (matching `deployment_list_params.py`'s `PropertyInfo(alias=...)`
    /// aliases). `status` is `"active"`/`"paused"`; omit for both -- cannot be combined with
    /// `includeArchived`.
    public func list(
        agentId: String? = nil,
        createdAtGte: String? = nil,
        createdAtLte: String? = nil,
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        status: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsDeployment> {
        try await client.transport.get(
            path: "v1/deployments",
            query: betaQuery.merging(
                [
                    "agent_id": agentId,
                    "created_at[gte]": createdAtGte,
                    "created_at[lte]": createdAtLte,
                    "include_archived": includeArchived.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                    "status": status,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive a deployment.
    public func archive(
        _ deploymentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeployment {
        try await client.transport.post(
            path: "v1/deployments/\(deploymentId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Pause a deployment.
    public func pause(
        _ deploymentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeployment {
        try await client.transport.post(
            path: "v1/deployments/\(deploymentId.asPathComponent)/pause",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Unpause a deployment.
    public func unpause(
        _ deploymentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeployment {
        try await client.transport.post(
            path: "v1/deployments/\(deploymentId.asPathComponent)/unpause",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Manually trigger a deployment run now, outside its schedule.
    public func run(
        _ deploymentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeploymentRun {
        try await client.transport.post(
            path: "v1/deployments/\(deploymentId.asPathComponent)/run",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var deployments: BetaDeployments { BetaDeployments(client: client) }
}
