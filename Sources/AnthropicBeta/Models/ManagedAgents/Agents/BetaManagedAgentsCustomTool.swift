import Anthropic

/// The JSON Schema for a custom tool's input, as returned in a response. Ported from
/// `beta_managed_agents_custom_tool_input_schema.py`.
public struct BetaManagedAgentsCustomToolInputSchema: Codable, Sendable, Equatable {
    public let type: String
    public let properties: [String: JSONValue]?
    public let required: [String]?

    public init(type: String = "object", properties: [String: JSONValue]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// A user-defined custom tool attached to an agent, as returned in a `BetaManagedAgentsAgent`
/// response. Ported from `beta_managed_agents_custom_tool.py`.
public struct BetaManagedAgentsCustomTool: Codable, Sendable, Equatable {
    public let description: String
    public let inputSchema: BetaManagedAgentsCustomToolInputSchema
    public let name: String
    public let type: String

    public init(
        description: String,
        inputSchema: BetaManagedAgentsCustomToolInputSchema,
        name: String,
        type: String = "custom"
    ) {
        self.description = description
        self.inputSchema = inputSchema
        self.name = name
        self.type = type
    }
}

/// Ported from `beta_managed_agents_custom_tool_input_schema_param.py`.
public struct BetaManagedAgentsCustomToolInputSchemaParams: Encodable, Sendable, Equatable {
    public let type = "object"
    public let properties: [String: JSONValue]?
    public let required: [String]?

    public init(properties: [String: JSONValue]? = nil, required: [String]? = nil) {
        self.properties = properties
        self.required = required
    }
}

/// Ported from `beta_managed_agents_custom_tool_params.py`.
public struct BetaManagedAgentsCustomToolParams: Encodable, Sendable, Equatable {
    public let description: String
    public let inputSchema: BetaManagedAgentsCustomToolInputSchemaParams
    public let name: String
    public let type = "custom"

    public init(description: String, inputSchema: BetaManagedAgentsCustomToolInputSchemaParams, name: String) {
        self.description = description
        self.inputSchema = inputSchema
        self.name = name
    }
}
