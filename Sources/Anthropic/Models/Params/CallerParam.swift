public enum CallerParam: Sendable, Equatable {
    case direct
    case codeExecution20250825(toolId: String)
    case codeExecution20260120(toolId: String)
}

extension CallerParam: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, toolId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .direct:
            try container.encode("direct", forKey: .type)
        case .codeExecution20250825(let toolId):
            try container.encode("code_execution_20250825", forKey: .type)
            try container.encode(toolId, forKey: .toolId)
        case .codeExecution20260120(let toolId):
            try container.encode("code_execution_20260120", forKey: .type)
            try container.encode(toolId, forKey: .toolId)
        }
    }
}
