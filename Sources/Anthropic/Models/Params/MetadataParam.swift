public struct MetadataParam: Encodable, Sendable, Equatable {
    public let userId: String?

    public init(userId: String? = nil) {
        self.userId = userId
    }
}
