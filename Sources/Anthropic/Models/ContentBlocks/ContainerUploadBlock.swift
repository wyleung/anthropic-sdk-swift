public struct ContainerUploadBlock: Codable, Sendable, Equatable {
    public let type = "container_upload"
    public let fileId: String

    private enum CodingKeys: String, CodingKey {
        case type, fileId
    }
}
