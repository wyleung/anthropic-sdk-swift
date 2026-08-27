import Anthropic

/// Ported from `agent_update_params.py`. Unlike `BetaEnvironmentUpdateParams` (Slice 1), no field
/// here needs a double-optional (`T??`) tri-state encoding -- every field's docstring collapses to
/// either a plain omit-or-value 2-state, or (for `metadata`) the already-proven per-key
/// dictionary-of-optionals pattern. That means this struct needs no custom `encode(to:)` at all:
/// Swift's synthesized `Encodable` conformance already omits a `nil`-valued `Optional` property's
/// key, and `[String: String?]` already encodes each per-key `nil` as JSON `null` rather than
/// omitting it (see `BetaWorkUpdateParams.metadata`/`BetaEnvironmentUpdateParams.metadata` for the
/// original confirmation of that dictionary behavior).
///
/// Field-by-field docstring semantics from the Python source:
/// - `description`/`system`: omit to preserve; any non-`nil` string (including `""`) sets/clears.
/// - `mcpServers`/`skills`/`tools`: full-replacement arrays; omit to preserve, empty array clears.
/// - `metadata`: per-key patch -- string upserts, `nil` deletes that key, omitted keys are
///   untouched.
/// - `model`: omit to preserve. Cannot be cleared (no PATCH-style null form exists for it).
/// - `name`/`version`: omit to preserve. Cannot be cleared; `version` is only used for an
///   optimistic-concurrency precondition check when present.
/// - `multiagent`: the one field whose Python docstring does **not** spell out omit-vs-null-vs-
///   value semantics the way its siblings do. Modeled here as a plain omit-or-value optional
///   (matching every other non-array field); if the API does support an explicit `null` to clear
///   multiagent config, that isn't reachable through this initializer today. Revisit if that gap
///   turns out to matter in practice.
public struct BetaAgentUpdateParams: Encodable, Sendable, Equatable {
    public let description: String?
    public let system: String?
    public let mcpServers: [BetaManagedAgentsURLMCPServerParams]?
    public let skills: [BetaManagedAgentsSkillParams]?
    public let tools: [BetaManagedAgentsAgentToolParams]?
    public let metadata: [String: String?]?
    public let model: BetaAgentModelParam?
    public let multiagent: BetaManagedAgentsMultiagentParams?
    public let name: String?
    public let version: Int?

    public init(
        description: String? = nil,
        system: String? = nil,
        mcpServers: [BetaManagedAgentsURLMCPServerParams]? = nil,
        skills: [BetaManagedAgentsSkillParams]? = nil,
        tools: [BetaManagedAgentsAgentToolParams]? = nil,
        metadata: [String: String?]? = nil,
        model: BetaAgentModelParam? = nil,
        multiagent: BetaManagedAgentsMultiagentParams? = nil,
        name: String? = nil,
        version: Int? = nil
    ) {
        self.description = description
        self.system = system
        self.mcpServers = mcpServers
        self.skills = skills
        self.tools = tools
        self.metadata = metadata
        self.model = model
        self.multiagent = multiagent
        self.name = name
        self.version = version
    }
}
