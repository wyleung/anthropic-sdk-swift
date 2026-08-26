import Anthropic

/// Ported from `types/beta/messages/beta_message_batch_succeeded_result.py`. Unlike GA's
/// `MessageBatchSucceededResult`, holds a `BetaMessage` rather than `Message`, so it can't be a
/// typealias.
public struct BetaMessageBatchSucceededResult: Codable, Sendable, Equatable {
    public let message: BetaMessage
    public let type: String
}

/// Ported from `types/beta/messages/beta_message_batch_errored_result.py`.
public struct BetaMessageBatchErroredResult: Codable, Sendable, Equatable {
    public let error: BetaErrorResponse
    public let type: String
}

/// Ported from `types/beta/messages/beta_message_batch_canceled_result.py`.
public struct BetaMessageBatchCanceledResult: Codable, Sendable, Equatable {
    public let type: String
}

/// Ported from `types/beta/messages/beta_message_batch_expired_result.py`.
public struct BetaMessageBatchExpiredResult: Codable, Sendable, Equatable {
    public let type: String
}

/// Ported from `types/beta/messages/beta_message_batch_result.py`'s 4-way discriminated union.
public enum BetaMessageBatchResult: Sendable, Equatable {
    case succeeded(BetaMessageBatchSucceededResult)
    case errored(BetaMessageBatchErroredResult)
    case canceled(BetaMessageBatchCanceledResult)
    case expired(BetaMessageBatchExpiredResult)
    case unknown(type: String, raw: JSONValue)
}

extension BetaMessageBatchResult: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "succeeded":
            self = .succeeded(try BetaMessageBatchSucceededResult(from: decoder))
        case "errored":
            self = .errored(try BetaMessageBatchErroredResult(from: decoder))
        case "canceled":
            self = .canceled(try BetaMessageBatchCanceledResult(from: decoder))
        case "expired":
            self = .expired(try BetaMessageBatchExpiredResult(from: decoder))
        default:
            self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .succeeded(let result): try result.encode(to: encoder)
        case .errored(let result): try result.encode(to: encoder)
        case .canceled(let result): try result.encode(to: encoder)
        case .expired(let result): try result.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/messages/beta_message_batch_individual_response.py`.
public struct BetaMessageBatchIndividualResponse: Codable, Sendable, Equatable {
    public let customId: String
    public let result: BetaMessageBatchResult
}
