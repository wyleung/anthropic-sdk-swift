public enum SystemPromptParam: Sendable, Equatable {
    case text(String)
    case blocks([TextBlockParam])
}

extension SystemPromptParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .blocks(let value): try container.encode(value)
        }
    }
}

extension SystemPromptParam: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}
