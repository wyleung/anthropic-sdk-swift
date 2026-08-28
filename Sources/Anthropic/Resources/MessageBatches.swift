import Foundation

/// Exposed as `client.messages.batches`, mirroring the reference SDKs nesting this resource under
/// their `messages/` module rather than as a flat top-level resource.
public struct MessageBatches: Sendable {
    unowned let client: AnthropicClient

    /// Send a batch of Message creation requests. `userProfileId` is sent as the
    /// `anthropic-user-profile-id` header (not a body field) to attribute every request in the
    /// batch to that user profile; requires the `user-profiles` beta header to be set separately.
    public func create(
        requests: [MessageBatchCreateParams.Request],
        userProfileId: String? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageBatch {
        var headers: [String: String?] = [:]
        if let userProfileId {
            headers["anthropic-user-profile-id"] = userProfileId
        }
        headers.merge(options.headers) { _, new in new }
        var mergedOptions = options
        mergedOptions.headers = headers

        return try await client.transport.send(
            method: "POST",
            path: "v1/messages/batches",
            body: MessageBatchCreateParams(requests: requests),
            options: mergedOptions
        )
    }

    /// This endpoint is idempotent and can be used to poll for Message Batch completion.
    public func retrieve(
        _ messageBatchId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageBatch {
        try await client.transport.get(path: "v1/messages/batches/\(messageBatchId.asPathComponent)", options: options)
    }

    /// List all Message Batches within a Workspace, most recently created first.
    public func list(
        afterId: String? = nil,
        beforeId: String? = nil,
        limit: Int? = nil,
        options: RequestOptions = RequestOptions()
    ) async throws -> Page<MessageBatch> {
        try await client.transport.get(
            path: "v1/messages/batches",
            query: [
                "after_id": afterId,
                "before_id": beforeId,
                "limit": limit.map(String.init),
            ],
            options: options
        )
    }

    /// Message Batches can only be deleted once they've finished processing; cancel an
    /// in-progress batch first.
    public func delete(
        _ messageBatchId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> DeletedMessageBatch {
        try await client.transport.delete(path: "v1/messages/batches/\(messageBatchId.asPathComponent)", options: options)
    }

    /// Cancel a batch any time before processing ends; the batch enters a `canceling` state.
    public func cancel(
        _ messageBatchId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> MessageBatch {
        try await client.transport.post(
            path: "v1/messages/batches/\(messageBatchId.asPathComponent)/cancel",
            options: options
        )
    }

    /// Fetches and decodes the `.jsonl` results file for a finished batch. Unlike the reference
    /// SDKs' `JSONLDecoder`/`AsyncJSONLDecoder` (a true streaming line decoder), this reads the
    /// full response body up front and decodes every line -- deferring true streaming as a later
    /// enhancement, matching this port's existing stance on pagination auto-iteration.
    public func results(
        _ messageBatchId: String,
        options: RequestOptions = RequestOptions()
    ) async throws -> [MessageBatchIndividualResponse] {
        let batch = try await retrieve(messageBatchId, options: options)
        guard let resultsUrl = batch.resultsUrl else {
            throw AnthropicError.responseValidation(
                message: "No `results_url` for batch \(messageBatchId); has it finished processing? "
                    + "processing_status=\(batch.processingStatus)",
                body: nil
            )
        }

        let data = try await client.transport.getData(
            path: resultsUrl, accept: "application/binary", options: options
        )
        return try data.split(separator: UInt8(ascii: "\n"))
            .filter { !$0.isEmpty }
            .map { try HTTPTransport.decoder.decode(MessageBatchIndividualResponse.self, from: Data($0)) }
    }
}

extension Messages {
    public var batches: MessageBatches { MessageBatches(client: client) }
}
