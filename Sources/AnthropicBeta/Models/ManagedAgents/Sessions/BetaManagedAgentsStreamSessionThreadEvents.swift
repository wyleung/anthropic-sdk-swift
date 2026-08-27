/// Ported from `beta_managed_agents_stream_session_thread_events.py`'s
/// `BetaManagedAgentsStreamSessionThreadEvents` -- a Python `TypeAlias` whose `Union` membership is
/// byte-identical to `BetaManagedAgentsStreamSessionEvents` (confirmed by diffing both unions'
/// member lists in full), not a nominally distinct type. A Swift `typealias` mirrors that exactly,
/// rather than duplicating the 37-case union.
public typealias BetaManagedAgentsStreamSessionThreadEvents = BetaManagedAgentsStreamSessionEvents
