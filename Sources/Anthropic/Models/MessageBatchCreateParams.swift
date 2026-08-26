/// Ported from `types/messages/batch_create_params.py`. `userProfileId` isn't a body field in the
/// reference SDKs despite living in the same params type -- it's lifted into the
/// `anthropic-user-profile-id` header by the resource method, so it isn't modeled here; see
/// `MessageBatches.create`.
public struct MessageBatchCreateParams: Encodable, Sendable, Equatable {
    /// A single request within a batch. Ported from `batch_create_params.Request`.
    public struct Request: Encodable, Sendable, Equatable {
        public let customId: String
        public let params: MessageCreateParams

        public init(customId: String, params: MessageCreateParams) {
            self.customId = customId
            self.params = params
        }
    }

    public let requests: [Request]

    public init(requests: [Request]) {
        self.requests = requests
    }
}
