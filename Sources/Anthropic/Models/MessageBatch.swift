/// Ported from `types/messages/message_batch_request_counts.py`.
public struct MessageBatchRequestCounts: Codable, Sendable, Equatable {
    public let canceled: Int
    public let errored: Int
    public let expired: Int
    public let processing: Int
    public let succeeded: Int
}

/// Ported from `types/messages/message_batch.py`. Date fields stay `String`, matching
/// `Container.expiresAt` -- this port's decoder has no ISO-8601 date strategy set.
public struct MessageBatch: Codable, Sendable, Equatable {
    public enum ProcessingStatus: Sendable, Equatable {
        case inProgress
        case canceling
        case ended
        case unknown(String)
    }

    public let id: String
    public let archivedAt: String?
    public let cancelInitiatedAt: String?
    public let createdAt: String
    public let endedAt: String?
    public let expiresAt: String
    public let processingStatus: ProcessingStatus
    public let requestCounts: MessageBatchRequestCounts
    public let resultsUrl: String?
    public let type: String
}

extension MessageBatch.ProcessingStatus: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "in_progress": self = .inProgress
        case "canceling": self = .canceling
        case "ended": self = .ended
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .inProgress: try container.encode("in_progress")
        case .canceling: try container.encode("canceling")
        case .ended: try container.encode("ended")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

/// Ported from `types/messages/deleted_message_batch.py`.
public struct DeletedMessageBatch: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
}
