public enum EffortLevel: String, Encodable, Sendable, Equatable {
    case low
    case medium
    case high
    case xhigh
    case max
}

public struct JSONOutputFormatParam: Encodable, Sendable, Equatable {
    public let type = "json_schema"
    public let schema: JSONValue

    public init(schema: JSONValue) {
        self.schema = schema
    }
}

public struct OutputConfigParam: Encodable, Sendable, Equatable {
    public let effort: EffortLevel?
    public let format: JSONOutputFormatParam?

    public init(effort: EffortLevel? = nil, format: JSONOutputFormatParam? = nil) {
        self.effort = effort
        self.format = format
    }
}
