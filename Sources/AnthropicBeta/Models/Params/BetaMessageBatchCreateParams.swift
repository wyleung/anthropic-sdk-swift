import Anthropic

/// Ported from `types/beta/messages/batch_create_params.py`. `betas`/`userProfileId` aren't body
/// fields in the Python source either -- they're lifted into headers by the resource method; see
/// `BetaMessageBatches.create`.
public struct BetaMessageBatchCreateParams: Encodable, Sendable, Equatable {
    /// A single request within a batch. Ported from `batch_create_params.Request`.
    public struct Request: Encodable, Sendable, Equatable {
        public let customId: String
        public let params: BetaMessageCreateParams

        public init(customId: String, params: BetaMessageCreateParams) {
            self.customId = customId
            self.params = params
        }
    }

    public let requests: [Request]

    public init(requests: [Request]) {
        self.requests = requests
    }
}
