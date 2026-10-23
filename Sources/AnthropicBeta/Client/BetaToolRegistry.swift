import Foundation
import Anthropic

/// The tool state of a `BetaToolRunner` that can change while a run is in flight: which local tools
/// can be dispatched, the `tool_addition` / `tool_removal` directives queued for the model's next
/// request, and a scheduled compaction.
///
/// `addTools`, `removeTools` and `compactBeforeNextTurn` can be called from anywhere -- a hook, another
/// task, or a tool body that is itself running in the runner's task group -- so everything here sits
/// behind one lock. The loop itself owns the conversation (`params`); this type never touches it.
final class BetaToolRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var toolsByName: [String: AnyAnthropicTool]
    /// Directives not yet sent to the model. They go out in one `system` message at the next request.
    private var pendingChanges: [BetaContentBlockParam] = []
    private var pendingCompaction: BetaCompactionConfigParam?

    init(tools: [AnyAnthropicTool]) {
        toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    // MARK: - Changes made while running

    /// Function tools run straight away, in place of any tool of the same name, even for a call already
    /// in the message being handled.
    func add(_ tools: [AnyAnthropicTool]) {
        locked {
            for tool in tools {
                toolsByName[tool.name] = tool
                pendingChanges.append(.toolAddition(BetaRequestToolAdditionBlockParam(
                    definition: .tool(.custom(tool.toolParam))
                )))
            }
        }
    }

    /// Raw definitions are for server tools: the runner never runs them, and stops running a function
    /// tool of the same name.
    func add(definitions: [BetaToolUnionParam]) {
        locked {
            for definition in definitions {
                if let name = Self.definitionName(definition) {
                    toolsByName.removeValue(forKey: name)
                }
                pendingChanges.append(.toolAddition(BetaRequestToolAdditionBlockParam(definition: definition)))
            }
        }
    }

    func remove(names: [String]) {
        locked {
            for name in names {
                toolsByName.removeValue(forKey: name)
                pendingChanges.append(.toolRemoval(BetaRequestToolRemovalBlockParam(
                    tool: .tool(BetaToolChangeToolReferenceParam(name: name))
                )))
            }
        }
    }

    func scheduleCompaction(_ compaction: BetaCompactionConfigParam) {
        locked { pendingCompaction = compaction }
    }

    // MARK: - What the loop reads

    /// The queued directives as the single `system` message that carries them, clearing the queue.
    func takePendingToolChangesMessage() -> BetaMessageParam? {
        locked {
            guard !pendingChanges.isEmpty else { return nil }
            defer { pendingChanges = [] }
            return BetaMessageParam(role: .system, content: pendingChanges)
        }
    }

    func takePendingCompaction() -> BetaCompactionConfigParam? {
        locked {
            defer { pendingCompaction = nil }
            return pendingCompaction
        }
    }

    func hasPendingCompaction() -> Bool {
        locked { pendingCompaction != nil }
    }

    func clearPendingCompaction() {
        locked { pendingCompaction = nil }
    }

    /// The tool to run for a call to `name`, or `nil` when it is unregistered or currently withdrawn.
    /// Looked up per call, at the moment it starts, so a tool added or removed by an earlier call of the
    /// same message is honored.
    func tool(named name: String, history: [BetaMessageParam]) -> AnyAnthropicTool? {
        locked {
            guard let tool = toolsByName[name] else { return nil }
            return availableNames(history: history).contains(name) ? tool : nil
        }
    }

    /// After a compaction replaces the history, a removal that lived only in the replaced messages would
    /// be forgotten, so it is applied to the registry itself.
    func dropWithdrawnTools(history: [BetaMessageParam]) {
        locked {
            let available = availableNames(history: history)
            for name in toolsByName.keys where !available.contains(name) {
                toolsByName.removeValue(forKey: name)
            }
        }
    }

    // MARK: - Availability

    /// Must be called with the lock held. Changes made since the last request are not in the history yet,
    /// so they are folded in last.
    private func availableNames(history: [BetaMessageParam]) -> Set<String> {
        var messages = history
        if !pendingChanges.isEmpty {
            messages.append(BetaMessageParam(role: .system, content: pendingChanges))
        }
        return Self.availableNames(base: Set(toolsByName.keys), messages: messages)
    }

    /// The set of tool names dispatchable right now: every locally-registered tool, with any
    /// `tool_removal`/`tool_addition` block already in the conversation folded in, in order. Those
    /// arrive in `system` messages, and in the `toolChanges` of a `compaction` block in an `assistant`
    /// message -- which stands in for the system messages of the turns it summarized, so ignoring it
    /// would forget every tool change made before the compaction.
    static func availableNames(base: Set<String>, messages: [BetaMessageParam]) -> Set<String> {
        var available = base
        for message in messages {
            for block in message.content {
                switch (message.role, block) {
                case (.system, .toolRemoval(let removal)):
                    if let name = referencedToolName(removal.tool) { available.remove(name) }
                case (.system, .toolAddition(let addition)):
                    if let name = addedToolName(addition.tool) { available.insert(name) }
                case (.assistant, .compaction(let compaction)):
                    for change in compaction.toolChanges ?? [] {
                        apply(change, to: &available)
                    }
                default:
                    continue
                }
            }
        }
        return available
    }

    /// Only a direct-by-name reference resolves to a locally dispatchable tool. MCP references name
    /// a server-side tool or an entire server's toolset -- neither is something the registry could
    /// ever hold, so both resolve to `nil` and are ignored for local dispatch.
    private static func referencedToolName(_ reference: BetaToolChangeReferenceParam) -> String? {
        switch reference {
        case .tool(let toolReference): return toolReference.name
        case .mcpTool, .mcpToolset: return nil
        }
    }

    /// An addition names a runnable tool either by reference or, for inline tools, by the `name` its
    /// full definition carries. Not every definition has one (an `mcp_toolset` doesn't), and those are
    /// never locally runnable.
    private static func addedToolName(_ target: BetaToolAdditionParam) -> String? {
        switch target {
        case .reference(let reference): return referencedToolName(reference)
        case .definition(let definition): return definitionName(definition.definition)
        }
    }

    private static func definitionName(_ definition: BetaToolUnionParam) -> String? {
        guard let data = try? HTTPTransport.encoder.encode(definition),
              let json = try? HTTPTransport.decoder.decode(JSONValue.self, from: data)
        else { return nil }
        return json["name"]?.stringValue
    }

    private static func apply(_ change: BetaCompactionToolChangeParam, to available: inout Set<String>) {
        switch change {
        case .removal(let removal):
            if let name = referencedToolName(removal.tool) { available.remove(name) }
        case .addition(let addition):
            if let name = addedToolName(addition.tool) { available.insert(name) }
        case .raw(let json):
            // A response block's entries, echoed verbatim. Unknown change or tool types are ignored
            // rather than failing -- forward compatibility, as upstream does.
            guard let type = json["type"]?.stringValue, let tool = json["tool"] else { return }
            let name: String?
            switch tool["type"]?.stringValue {
            case "tool_reference": name = tool["name"]?.stringValue
            case "tool_definition": name = tool["definition"]?["name"]?.stringValue
            default: name = nil
            }
            guard let name else { return }
            if type == "tool_removal" { available.remove(name) } else if type == "tool_addition" { available.insert(name) }
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
