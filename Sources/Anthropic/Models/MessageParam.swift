public struct MessageParam: Encodable, Sendable, Equatable {
    public var role: Role
    public var content: [ContentBlockParam]

    public init(role: Role, content: [ContentBlockParam]) {
        self.role = role
        self.content = content
    }

    public static func user(_ text: String) -> MessageParam {
        MessageParam(role: .user, content: [.text(TextBlockParam(text: text))])
    }

    public static func assistant(_ text: String) -> MessageParam {
        MessageParam(role: .assistant, content: [.text(TextBlockParam(text: text))])
    }
}
