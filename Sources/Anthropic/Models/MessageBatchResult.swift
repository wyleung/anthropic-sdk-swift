/// Ported from `types/messages/message_batch_succeeded_result.py`.
public struct MessageBatchSucceededResult: Codable, Sendable, Equatable {
    public let message: Message
    public let type: String
}

/// Ported from `types/messages/message_batch_errored_result.py`.
public struct MessageBatchErroredResult: Codable, Sendable, Equatable {
    public let error: ErrorResponse
    public let type: String
}

/// Ported from `types/messages/message_batch_canceled_result.py`.
public struct MessageBatchCanceledResult: Codable, Sendable, Equatable {
    public let type: String
}

/// Ported from `types/messages/message_batch_expired_result.py`.
public struct MessageBatchExpiredResult: Codable, Sendable, Equatable {
    public let type: String
}

/// Ported from `types/messages/message_batch_result.py`'s 4-way discriminated union.
public enum MessageBatchResult: Sendable, Equatable {
    case succeeded(MessageBatchSucceededResult)
    case errored(MessageBatchErroredResult)
    case canceled(MessageBatchCanceledResult)
    case expired(MessageBatchExpiredResult)
    case unknown(type: String, raw: JSONValue)
}

extension MessageBatchResult: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "succeeded":
            self = .succeeded(try MessageBatchSucceededResult(from: decoder))
        case "errored":
            self = .errored(try MessageBatchErroredResult(from: decoder))
        case "canceled":
            self = .canceled(try MessageBatchCanceledResult(from: decoder))
        case "expired":
            self = .expired(try MessageBatchExpiredResult(from: decoder))
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

/// Ported from `types/messages/message_batch_individual_response.py`.
public struct MessageBatchIndividualResponse: Codable, Sendable, Equatable {
    public let customId: String
    public let result: MessageBatchResult
}
