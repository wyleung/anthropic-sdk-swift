public struct ToolChoiceAutoParam: Encodable, Sendable, Equatable {
    public let type = "auto"
    public let disableParallelToolUse: Bool?

    public init(disableParallelToolUse: Bool? = nil) {
        self.disableParallelToolUse = disableParallelToolUse
    }
}

public struct ToolChoiceAnyParam: Encodable, Sendable, Equatable {
    public let type = "any"
    public let disableParallelToolUse: Bool?

    public init(disableParallelToolUse: Bool? = nil) {
        self.disableParallelToolUse = disableParallelToolUse
    }
}

public struct ToolChoiceToolParam: Encodable, Sendable, Equatable {
    public let type = "tool"
    public let name: String
    public let disableParallelToolUse: Bool?

    public init(name: String, disableParallelToolUse: Bool? = nil) {
        self.name = name
        self.disableParallelToolUse = disableParallelToolUse
    }
}

public struct ToolChoiceNoneParam: Encodable, Sendable, Equatable {
    public let type = "none"

    public init() {}
}

public enum ToolChoiceParam: Sendable, Equatable {
    case auto(ToolChoiceAutoParam)
    case any(ToolChoiceAnyParam)
    case tool(ToolChoiceToolParam)
    case none(ToolChoiceNoneParam)
}

extension ToolChoiceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .auto(let value): try value.encode(to: encoder)
        case .any(let value): try value.encode(to: encoder)
        case .tool(let value): try value.encode(to: encoder)
        case .none(let value): try value.encode(to: encoder)
        }
    }
}
