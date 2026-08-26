public struct Message: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let role: Role
    public let content: [ContentBlock]
    public let model: String
    public let container: Container?
    public let stopReason: StopReason?
    public let stopSequence: String?
    public let stopDetails: RefusalStopDetails?
    public let usage: Usage
}
