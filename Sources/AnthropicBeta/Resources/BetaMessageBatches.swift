import Anthropic
import Foundation

/// Exposed as `client.beta.messages.batches`, mirroring GA's `MessageBatches` nesting. Every
/// method sends `betaQuery` and merges in the mandatory `message-batches-2024-09-24` beta header
/// via `betaRequestOptions` -- confirmed required on all six endpoints by reading
/// `resources/beta/messages/batches.py` directly, not just assumed from `create`.
public struct BetaMessageBatches: Sendable {
    unowned let client: AnthropicClient

    /// Send a batch of Message creation requests. `userProfileId` is sent as the
    /// `anthropic-user-profile-id` header (not a body field), matching GA's `MessageBatches.create`.
    public func create(
        requests: [BetaMessageBatchCreateParams.Request],
        betas: [String] = [],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaMessageBatch {
        try await client.transport.send(
            method: "POST",
            path: "v1/messages/batches",
            query: betaQuery,
            body: BetaMessageBatchCreateParams(requests: requests),
            options: betaRequestOptions(
                betas: betas,
                requiredBeta: "message-batches-2024-09-24",
                userProfileId: userProfileId,
                base: options
            )
        )
    }

    /// This endpoint is idempotent and can be used to poll for Message Batch completion.
    public func retrieve(
        _ messageBatchId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaMessageBatch {
        try await client.transport.get(
            path: "v1/messages/batches/\(messageBatchId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "message-batches-2024-09-24", base: options)
        )
    }

    /// List all Message Batches within a Workspace, most recently created first.
    public func list(
        afterId: String? = nil,
        beforeId: String? = nil,
        limit: Int? = nil,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<BetaMessageBatch> {
        try await client.transport.get(
            path: "v1/messages/batches",
            query: betaQuery.merging(
                [
                    "after_id": afterId,
                    "before_id": beforeId,
                    "limit": limit.map(String.init),
                ]
            ) { _, new in new },
            options: betaRequestOptions(betas: betas, requiredBeta: "message-batches-2024-09-24", base: options)
        )
    }

    /// Message Batches can only be deleted once they've finished processing; cancel an
    /// in-progress batch first.
    public func delete(
        _ messageBatchId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaDeletedMessageBatch {
        try await client.transport.delete(
            path: "v1/messages/batches/\(messageBatchId.asPathComponent)",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "message-batches-2024-09-24", base: options)
        )
    }

    /// Cancel a batch any time before processing ends; the batch enters a `canceling` state.
    public func cancel(
        _ messageBatchId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> BetaMessageBatch {
        try await client.transport.post(
            path: "v1/messages/batches/\(messageBatchId.asPathComponent)/cancel",
            query: betaQuery,
            options: betaRequestOptions(betas: betas, requiredBeta: "message-batches-2024-09-24", base: options)
        )
    }

    /// Fetches and decodes the `.jsonl` results file for a finished batch, matching GA's
    /// `MessageBatches.results` one-shot-decode approach. Matching the Python reference exactly,
    /// the interim `retrieve` call below does not forward `betas` -- only the final results fetch
    /// does; both still always carry the mandatory beta flag via `betaRequestOptions`.
    public func results(
        _ messageBatchId: String,
        betas: [String] = [],
        options: RequestOptions = RequestOptions()
    ) async throws -> [BetaMessageBatchIndividualResponse] {
        let batch = try await retrieve(messageBatchId, options: options)
        guard let resultsUrl = batch.resultsUrl else {
            throw AnthropicError.responseValidation(
                message: "No `results_url` for batch \(messageBatchId); has it finished processing? "
                    + "processing_status=\(batch.processingStatus)",
                body: nil
            )
        }

        let data = try await client.transport.getData(
            path: resultsUrl,
            accept: "application/binary",
            options: betaRequestOptions(betas: betas, requiredBeta: "message-batches-2024-09-24", base: options)
        )
        return try data.split(separator: UInt8(ascii: "\n"))
            .filter { !$0.isEmpty }
            .map { try Self.jsonlDecoder.decode(BetaMessageBatchIndividualResponse.self, from: Data($0)) }
    }

    /// `HTTPTransport.decoder` (same `.convertFromSnakeCase` config) is `internal` to the
    /// `Anthropic` module, not `package`, so it isn't reachable from here -- this mirrors its
    /// configuration locally rather than widening GA's access level for one call site.
    private static let jsonlDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension BetaMessages {
    public var batches: BetaMessageBatches { BetaMessageBatches(client: client) }
}
