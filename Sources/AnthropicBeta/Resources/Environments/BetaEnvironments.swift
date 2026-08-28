import Anthropic

/// Exposed as `client.beta.environments`, mirroring `resources/beta/environments/environments.py`.
/// Every method sends `betaQuery` and merges in the mandatory `managed-agents-2026-04-01` beta
/// header via `betaRequestOptions`, confirmed required on all six endpoints by reading the Python
/// resource file directly.
public struct BetaEnvironments: Sendable {
    unowned let client: AnthropicClient

    static let requiredBeta = "managed-agents-2026-04-01"

    /// Create a new environment.
    public func create(
        _ params: BetaEnvironmentCreateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaEnvironment {
        try await client.transport.send(
            method: "POST",
            path: "v1/environments",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Retrieve an environment by ID.
    public func retrieve(
        _ environmentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaEnvironment {
        try await client.transport.get(
            path: "v1/environments/\(environmentId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Update an environment. Every field in `params` is a PATCH-merge -- see
    /// `BetaEnvironmentUpdateParams` for the omit/null/value semantics of each field.
    public func update(
        _ environmentId: String,
        _ params: BetaEnvironmentUpdateParams,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaEnvironment {
        try await client.transport.send(
            method: "POST",
            path: "v1/environments/\(environmentId.asPathComponent)",
            query: betaQuery,
            body: params,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// List environments, most recently created first.
    public func list(
        includeArchived: Bool? = nil,
        limit: Int? = nil,
        page: String? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> PageCursor<BetaEnvironment> {
        try await client.transport.get(
            path: "v1/environments",
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

    /// Permanently delete an environment.
    public func delete(
        _ environmentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaEnvironmentDeleteResponse {
        try await client.transport.delete(
            path: "v1/environments/\(environmentId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }

    /// Archive an environment.
    public func archive(
        _ environmentId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaEnvironment {
        try await client.transport.post(
            path: "v1/environments/\(environmentId.asPathComponent)/archive",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: Self.requiredBeta, base: options)
        )
    }
}

extension Beta {
    public var environments: BetaEnvironments { BetaEnvironments(client: client) }
}
