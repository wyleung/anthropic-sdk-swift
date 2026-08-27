import Anthropic

/// Placeholder `processedAt` for a preview snapshot until the buffered final event, which carries
/// the real timestamp, replaces it. Ported from `_accumulate.py`'s `_UNPROCESSED` (the Unix epoch).
private let unprocessedPlaceholder = "1970-01-01T00:00:00Z"

/// Folds one preview event into an `agent.message` snapshot. Returns a fresh snapshot -- the
/// `accumulated` argument is never mutated (guaranteed here by Swift value semantics, unlike
/// Python's `model_copy(deep=True)`). Ported field-for-field from
/// `lib/sessions/_accumulate.py`'s `accumulate_managed_agents_event`.
///
/// - `event_start` opens the preview: a new snapshot with empty content is returned (so
///   `accumulated` may be `nil`). Its `processedAt` is an epoch placeholder that the buffered final
///   event's server timestamp replaces. `accumulated` is passed through unchanged when the
///   previewed event is not an `agent.message` -- this helper only tracks `agent.message` previews.
/// - `event_delta` is folded into `accumulated`: a new `delta.index` inserts the fragment as a
///   fresh content entry; an existing index returns a copy with that entry appended to. An
///   unrecognised fragment type on an existing index passes the entry through unchanged -- deltas
///   are best-effort and the buffered final event is canonical.
/// - `agent.message` is the buffered final event: it replaces whatever the preview had accumulated.
///
/// Unlike Python, this is a single signature (no narrower overload for a bare
/// `BetaManagedAgentsAgentMessageEvent` input) -- Swift has no equivalent to that overload's
/// static-typing convenience, and the general signature already covers every caller.
public func accumulateManagedAgentsEvent(
    _ accumulated: BetaManagedAgentsAgentMessageEvent?,
    _ event: BetaManagedAgentsStreamSessionEvents
) throws -> BetaManagedAgentsAgentMessageEvent? {
    switch event {
    case .startEvent(let start):
        switch start.event {
        case .agentMessage(let preview):
            return BetaManagedAgentsAgentMessageEvent(
                content: [], id: preview.id, processedAt: unprocessedPlaceholder
            )
        case .agentThinking, .unknown:
            return accumulated
        }

    case .agentMessage(let final):
        return final

    case .deltaEvent(let deltaEvent):
        guard let accumulated else {
            throw AnthropicError.responseValidation(
                message: "event_delta for \(deltaEvent.eventId) received before its event_start",
                body: nil
            )
        }

        let idx = deltaEvent.delta.index ?? 0
        let fragment = deltaEvent.delta.content

        guard idx <= accumulated.content.count else {
            throw AnthropicError.responseValidation(
                message: "event_delta index \(idx) is beyond the end of content (length \(accumulated.content.count))",
                body: nil
            )
        }

        var content = accumulated.content
        if idx == content.count {
            content.append(.text(fragment))
        } else if case .text(let existing) = content[idx] {
            content[idx] = .text(BetaManagedAgentsTextBlock(text: existing.text + fragment.text))
        }

        return BetaManagedAgentsAgentMessageEvent(
            content: content, id: accumulated.id, processedAt: accumulated.processedAt
        )

    default:
        return accumulated
    }
}
