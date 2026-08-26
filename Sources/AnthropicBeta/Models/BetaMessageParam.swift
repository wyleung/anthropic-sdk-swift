import Anthropic

/// Ported from `types/beta/beta_message_param.py`. Mirrors GA's `MessageParam` exactly, except
/// `role` is `BetaRole` (adds `.system`) and `content` is `[BetaContentBlockParam]`.
public struct BetaMessageParam: Encodable, Sendable, Equatable {
    public var role: BetaRole
    public var content: [BetaContentBlockParam]

    public init(role: BetaRole, content: [BetaContentBlockParam]) {
        self.role = role
        self.content = content
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
