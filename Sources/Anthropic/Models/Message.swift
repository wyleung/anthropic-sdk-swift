public struct Message: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let role: Role
    public let content: [ContentBlock]
    /// Why the prompt cache couldn't fully reuse a prior request's prefix. Only present when the
    /// request supplied `MessageCreateParams.diagnostics`; `nil` otherwise.
    public let diagnostics: Diagnostics?
    public let model: String
    public let container: Container?
    public let stopReason: StopReason?
    public let stopSequence: String?
    public let stopDetails: RefusalStopDetails?
    public let usage: Usage
}
