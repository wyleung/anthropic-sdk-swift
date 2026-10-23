import Anthropic

/// Ported from `types/beta/beta_message_param.py`. Mirrors GA's `MessageParam`, except `role` is
/// `BetaRole` (adds `.system`), `content` is `[BetaContentBlockParam]`, and a `system` message can carry
/// the two fields upstream's `BetaSystemMessageParam` adds (`clearAt`, `outputConfig`). Upstream splits
/// this into a union by role; one struct encodes the same JSON.
public struct BetaMessageParam: Encodable, Sendable, Equatable {
    public var role: BetaRole
    public var content: [BetaContentBlockParam]
    /// How long this system message's text stays in front of the model. Only permitted on `system`.
    public var clearAt: BetaSystemMessageClearAt?
    /// Per-turn output configuration. Only permitted on `system`.
    public var outputConfig: BetaSystemMessageOutputConfigParam?

    public init(
        role: BetaRole,
        content: [BetaContentBlockParam],
        clearAt: BetaSystemMessageClearAt? = nil,
        outputConfig: BetaSystemMessageOutputConfigParam? = nil
    ) {
        self.role = role
        self.content = content
        self.clearAt = clearAt
        self.outputConfig = outputConfig
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, clearAt, outputConfig
    }

    /// A `system` message's `content` is optional, so one that carries only an `outputConfig` leaves it
    /// out instead of sending an empty list, which the API reads as a message with no content.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        if !(role == .system && content.isEmpty && (outputConfig != nil || clearAt != nil)) {
            try container.encode(content, forKey: .content)
        }
        try container.encodeIfPresent(clearAt, forKey: .clearAt)
        try container.encodeIfPresent(outputConfig, forKey: .outputConfig)
    }

    public static func user(_ text: String) -> BetaMessageParam {
        BetaMessageParam(role: .user, content: [.standard(.text(TextBlockParam(text: text)))])
    }

    public static func assistant(_ text: String) -> BetaMessageParam {
        BetaMessageParam(role: .assistant, content: [.standard(.text(TextBlockParam(text: text)))])
    }

    public static func system(_ text: String) -> BetaMessageParam {
        BetaMessageParam(role: .system, content: [.standard(.text(TextBlockParam(text: text)))])
    }
}
