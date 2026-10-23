import Anthropic

/// Per-message output configuration on a `role: "system"` input message. Ported from
/// `types/beta/beta_system_message_output_config_param.py`. Fields here apply per turn; `format` stays
/// top-level only (``BetaOutputConfigParam``), which is why this carries `effort` alone.
public struct BetaSystemMessageOutputConfigParam: Encodable, Sendable, Equatable {
    /// How much effort the model should put into its response. Higher levels may be more thorough but
    /// take longer.
    public let effort: EffortLevel?

    public init(effort: EffortLevel? = nil) {
        self.effort = effort
    }
}

/// How long a system message's text stays in front of the model. Ported from the `clear_at` field of
/// `types/beta/beta_system_message_param.py`. Only permitted on `role: "system"` messages.
public enum BetaSystemMessageClearAt: String, Encodable, Sendable, Equatable {
    /// Rendered on every request that includes the message (the default).
    case never
    /// Rendered only for the user turn it follows: once a later `user` message exists in `messages` the
    /// message stays in the array (send it unchanged) but is no longer shown to the model.
    case nextUserMessage = "next_user_message"
}
