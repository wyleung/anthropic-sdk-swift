import Foundation
import Anthropic

/// Follows a streamed reply and says when the model has moved on from a tool call, which is when
/// `BetaToolRunner` may start running it ahead of the reply's end (`runToolsEagerly`).
///
/// A call's own `content_block_stop` is not enough: a reply that is cut off closes its last call too,
/// with whatever input had arrived. Only the next block starting, or a `message_delta` that ends the
/// turn with `tool_use`, shows the call was finished on purpose. After a `fallback` block no call is
/// started, because the refusal that led to the fallback may have cut off the call before it, so the
/// rest wait for the reply to end. Mirrors upstream's `EagerToolCalls.track`.
struct BetaEagerCallTracker {
    private var closed: ToolUseBlock?
    private var afterFallback = false

    /// Returns the call that `event` shows the model has moved on from, if any.
    mutating func track(_ event: BetaMessageStreamEvent) -> ToolUseBlock? {
        switch event {
        case .contentBlockStop(let stop):
            if case .toolUse(let toolUse) = stop.contentBlock {
                closed = afterFallback ? nil : toolUse
            }
            return nil
        case .contentBlockStart(let start):
            if case .fallback = start.contentBlock {
                afterFallback = true
                closed = nil
                return nil
            }
            return takeClosed()
        case .messageDelta(let delta):
            return delta.delta.stopReason == .toolUse ? takeClosed() : nil
        default:
            return nil
        }
    }

    private mutating func takeClosed() -> ToolUseBlock? {
        defer { closed = nil }
        return closed
    }
}

/// The tool calls a runner started while a reply was still streaming, by `tool_use` id. They run as
/// tasks of their own, concurrently with each other and with the rest of the reply.
final class BetaEagerToolCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [String: Task<ToolResultBlockParam, Never>] = [:]

    func start(_ call: ToolUseBlock, run: @escaping @Sendable () async -> ToolResultBlockParam) {
        let task = Task { await run() }
        lock.lock()
        tasks[call.id] = task
        lock.unlock()
    }

    func started() -> [String: Task<ToolResultBlockParam, Never>] {
        lock.lock()
        defer { lock.unlock() }
        return tasks
    }

    /// Waits for every started call to finish, without using its result. A turn that does not run tools
    /// (it ended on `max_tokens`, say) still leaves the calls it started behind, and no work may outlive
    /// the run: they have begun, so they are finished, not cancelled.
    func settle() async {
        for task in started().values {
            _ = await task.value
        }
    }

    func cancelAll() {
        for task in started().values {
            task.cancel()
        }
    }

    func reset() {
        lock.lock()
        tasks = [:]
        lock.unlock()
    }
}
