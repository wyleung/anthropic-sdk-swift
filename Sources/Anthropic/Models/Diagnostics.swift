/// Request-level diagnostics: why the prompt cache could not fully reuse the prefix of the request
/// named by `diagnostics.previousMessageId` (see `DiagnosticsParam`). Ported from
/// `types/diagnostics.py`.
///
/// `cacheMissReason` is `nil` while the diagnosis is still pending -- the response was serialized
/// before the server's background comparison completed.
public struct Diagnostics: Codable, Sendable, Equatable {
    public let cacheMissReason: CacheMissReason?
}

/// A `cache_miss_reason` for a request whose `model` or `speed` differs from the previous request's.
/// Ported from `types/cache_miss_model_changed.py`.
public struct CacheMissModelChanged: Codable, Sendable, Equatable {
    public let type = "model_changed"
    public let cacheMissedInputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case type, cacheMissedInputTokens
    }
}

/// A `cache_miss_reason` for a request whose `system` differs from the previous request's.
/// Ported from `types/cache_miss_system_changed.py`.
public struct CacheMissSystemChanged: Codable, Sendable, Equatable {
    public let type = "system_changed"
    public let cacheMissedInputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case type, cacheMissedInputTokens
    }
}

/// A `cache_miss_reason` for a request whose `tools` differ from the previous request's.
/// Ported from `types/cache_miss_tools_changed.py`.
public struct CacheMissToolsChanged: Codable, Sendable, Equatable {
    public let type = "tools_changed"
    public let cacheMissedInputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case type, cacheMissedInputTokens
    }
}

/// A `cache_miss_reason` for a request whose `messages` differ from the previous request's.
/// Ported from `types/cache_miss_messages_changed.py`.
public struct CacheMissMessagesChanged: Codable, Sendable, Equatable {
    public let type = "messages_changed"
    public let cacheMissedInputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case type, cacheMissedInputTokens
    }
}

/// A `cache_miss_reason` for when the API has no stored record of the request that
/// `diagnostics.previousMessageId` references. This doesn't mean this request changed. Ported from
/// `types/cache_miss_previous_message_not_found.py`.
public struct CacheMissPreviousMessageNotFound: Codable, Sendable, Equatable {
    public let type = "previous_message_not_found"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// A `cache_miss_reason` for when the API can't give a diagnosis. The request itself was processed
/// normally -- this includes one whose `model`, `system` and `tools` match the previous request's
/// but whose other prompt-affecting parameters, such as `thinking` or `toolChoice`, differ. Ported
/// from `types/cache_miss_unavailable.py`.
public struct CacheMissUnavailable: Codable, Sendable, Equatable {
    public let type = "unavailable"

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// Ported from `types/cache_miss_reason.py`'s 6-case discriminated union. See the
/// [cache diagnostics guide](https://platform.claude.com/docs/en/build-with-claude/cache-diagnostics#cache-miss-reason-types)
/// for what to change for each reason.
public enum CacheMissReason: Sendable, Equatable {
    case modelChanged(CacheMissModelChanged)
    case systemChanged(CacheMissSystemChanged)
    case toolsChanged(CacheMissToolsChanged)
    case messagesChanged(CacheMissMessagesChanged)
    case previousMessageNotFound(CacheMissPreviousMessageNotFound)
    case unavailable(CacheMissUnavailable)
    case unknown(type: String, raw: JSONValue)
}

extension CacheMissReason: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "model_changed": self = .modelChanged(try CacheMissModelChanged(from: decoder))
        case "system_changed": self = .systemChanged(try CacheMissSystemChanged(from: decoder))
        case "tools_changed": self = .toolsChanged(try CacheMissToolsChanged(from: decoder))
        case "messages_changed": self = .messagesChanged(try CacheMissMessagesChanged(from: decoder))
        case "previous_message_not_found":
            self = .previousMessageNotFound(try CacheMissPreviousMessageNotFound(from: decoder))
        case "unavailable": self = .unavailable(try CacheMissUnavailable(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .modelChanged(let value): try value.encode(to: encoder)
        case .systemChanged(let value): try value.encode(to: encoder)
        case .toolsChanged(let value): try value.encode(to: encoder)
        case .messagesChanged(let value): try value.encode(to: encoder)
        case .previousMessageNotFound(let value): try value.encode(to: encoder)
        case .unavailable(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
