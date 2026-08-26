public struct ContainerUploadBlockParam: Encodable, Sendable, Equatable {
    public let type = "container_upload"
    public let fileId: String
    public let cacheControl: CacheControlEphemeral?

    public init(fileId: String, cacheControl: CacheControlEphemeral? = nil) {
        self.fileId = fileId
        self.cacheControl = cacheControl
    }
}
