import Anthropic

/// Ported from `types/beta/beta_response_tool_change_tool_reference.py`.
public struct BetaResponseToolChangeToolReference: Codable, Sendable, Equatable {
    public let type = "tool_reference"
    public let name: String

    private enum CodingKeys: String, CodingKey {
        case type, name
    }
}

/// Ported from `types/beta/beta_response_tool_change_mcp_tool_reference.py`.
public struct BetaResponseToolChangeMCPToolReference: Codable, Sendable, Equatable {
    public let type = "mcp_tool_reference"
    public let name: String
    public let serverName: String

    private enum CodingKeys: String, CodingKey {
        case type, name, serverName
    }
}

/// Ported from `types/beta/beta_response_tool_change_mcp_toolset_reference.py`.
public struct BetaResponseToolChangeMCPToolsetReference: Codable, Sendable, Equatable {
    public let type = "mcp_toolset_reference"
    public let serverName: String

    private enum CodingKeys: String, CodingKey {
        case type, serverName
    }
}

/// A tool added mid-conversation by its full definition. Ported from
/// `types/beta/beta_tool_change_tool_definition.py`.
///
/// `definition` is a raw `JSONValue`: upstream types it as `BetaResponseToolUnion`, a ~28-member union
/// that echoes every tool definition type back in response form. It round-trips losslessly into
/// `BetaToolChangeToolDefinitionParam.definition` through `BetaToolUnionParam.raw`.
public struct BetaToolChangeToolDefinition: Codable, Sendable, Equatable {
    public let type = "tool_definition"
    public let definition: JSONValue

    private enum CodingKeys: String, CodingKey {
        case type, definition
    }
}

/// The tool a `tool_removal` block withdraws. Ported from `BetaResponseToolRemovalBlock.Tool`.
public enum BetaResponseToolRemovalTarget: Sendable, Equatable {
    case tool(BetaResponseToolChangeToolReference)
    case mcpTool(BetaResponseToolChangeMCPToolReference)
    case mcpToolset(BetaResponseToolChangeMCPToolsetReference)
    case unknown(type: String, raw: JSONValue)
}

/// The tool a `tool_addition` block surfaces -- a removal target, or a full definition. Ported from
/// `BetaResponseToolAdditionBlock.Tool`.
public enum BetaResponseToolAdditionTarget: Sendable, Equatable {
    case tool(BetaResponseToolChangeToolReference)
    case mcpTool(BetaResponseToolChangeMCPToolReference)
    case mcpToolset(BetaResponseToolChangeMCPToolsetReference)
    case definition(BetaToolChangeToolDefinition)
    case unknown(type: String, raw: JSONValue)
}

private enum ToolChangeDiscriminator: String, CodingKey {
    case type
}

extension BetaResponseToolRemovalTarget: Codable {
    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: ToolChangeDiscriminator.self).decode(String.self, forKey: .type)
        switch type {
        case "tool_reference": self = .tool(try BetaResponseToolChangeToolReference(from: decoder))
        case "mcp_tool_reference": self = .mcpTool(try BetaResponseToolChangeMCPToolReference(from: decoder))
        case "mcp_toolset_reference": self = .mcpToolset(try BetaResponseToolChangeMCPToolsetReference(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tool(let value): try value.encode(to: encoder)
        case .mcpTool(let value): try value.encode(to: encoder)
        case .mcpToolset(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

extension BetaResponseToolAdditionTarget: Codable {
    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: ToolChangeDiscriminator.self).decode(String.self, forKey: .type)
        switch type {
        case "tool_reference": self = .tool(try BetaResponseToolChangeToolReference(from: decoder))
        case "mcp_tool_reference": self = .mcpTool(try BetaResponseToolChangeMCPToolReference(from: decoder))
        case "mcp_toolset_reference": self = .mcpToolset(try BetaResponseToolChangeMCPToolsetReference(from: decoder))
        case "tool_definition": self = .definition(try BetaToolChangeToolDefinition(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tool(let value): try value.encode(to: encoder)
        case .mcpTool(let value): try value.encode(to: encoder)
        case .mcpToolset(let value): try value.encode(to: encoder)
        case .definition(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}

/// Ported from `types/beta/beta_response_tool_addition_block.py`.
public struct BetaResponseToolAdditionBlock: Codable, Sendable, Equatable {
    public let type = "tool_addition"
    public let tool: BetaResponseToolAdditionTarget

    private enum CodingKeys: String, CodingKey {
        case type, tool
    }
}

/// Ported from `types/beta/beta_response_tool_removal_block.py`.
public struct BetaResponseToolRemovalBlock: Codable, Sendable, Equatable {
    public let type = "tool_removal"
    public let tool: BetaResponseToolRemovalTarget

    private enum CodingKeys: String, CodingKey {
        case type, tool
    }
}

/// An entry of `BetaCompactionBlock.toolChanges`: the tool additions and removals in effect when the
/// conversation was compacted. Ported from `BetaCompactionBlock.ToolChange`.
public enum BetaCompactionToolChange: Sendable, Equatable {
    case addition(BetaResponseToolAdditionBlock)
    case removal(BetaResponseToolRemovalBlock)
    case unknown(type: String, raw: JSONValue)
}

extension BetaCompactionToolChange: Codable {
    public init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: ToolChangeDiscriminator.self).decode(String.self, forKey: .type)
        switch type {
        case "tool_addition": self = .addition(try BetaResponseToolAdditionBlock(from: decoder))
        case "tool_removal": self = .removal(try BetaResponseToolRemovalBlock(from: decoder))
        default: self = .unknown(type: type, raw: try JSONValue(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .addition(let value): try value.encode(to: encoder)
        case .removal(let value): try value.encode(to: encoder)
        case .unknown(_, let raw): try raw.encode(to: encoder)
        }
    }
}
