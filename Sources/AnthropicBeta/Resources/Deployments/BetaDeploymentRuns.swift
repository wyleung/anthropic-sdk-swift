import Anthropic

/// Exposed as `client.beta.deploymentRuns`, mirroring `resources/beta/deployment_runs.py`. Retrieve
/// and list only -- runs are an append-only record, never created or mutated directly (creation
/// happens as a side effect of `BetaDeployments.run` or a fired schedule).
public struct BetaDeploymentRuns: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Retrieve a deployment run by ID.
    public func retrieve(
        _ deploymentRunId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaManagedAgentsDeploymentRun {
        try await client.transport.get(
            path: "v1/deployment_runs/\(deploymentRunId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List deployment runs, most recently created first. `createdAtGt`/`createdAtGte`/
    /// `createdAtLt`/`createdAtLte` are pre-formatted ISO8601 timestamp strings, sent as the literal
    /// `created_at[gt]`/`created_at[gte]`/`created_at[lt]`/`created_at[lte]` query keys. `hasError`
    /// filters to failed (`true`) vs. succeeded (`false`) runs; omit for all. `triggerType` is
    /// `"schedule"`/`"manual"`.
    public func list(
        createdAtGt: String? = nil,
        createdAtGte: String? = nil,
        createdAtLt: String? = nil,
        createdAtLte: String? = nil,
        deploymentId: String? = nil,
        hasError: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        triggerType: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaManagedAgentsDeploymentRun> {
        try await client.transport.get(
            path: "v1/deployment_runs",
            query: betaQuery.merging(
                [
                    "created_at[gt]": createdAtGt,
                    "created_at[gte]": createdAtGte,
                    "created_at[lt]": createdAtLt,
                    "created_at[lte]": createdAtLte,
                    "deployment_id": deploymentId,
                    "has_error": hasError.map { $0 ? "true" : "false" },
                    "limit": limit.map(String.init),
                    "page": page,
                    "trigger_type": triggerType,
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var deploymentRuns: BetaDeploymentRuns { BetaDeploymentRuns(client: client) }
}
