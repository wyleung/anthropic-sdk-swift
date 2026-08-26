public struct Base64ImageSourceParam: Encodable, Sendable, Equatable {
    public enum MediaType: String, Encodable, Sendable, Equatable {
        case jpeg = "image/jpeg"
        case png = "image/png"
        case gif = "image/gif"
        case webp = "image/webp"
    }

    public let type = "base64"
    public let mediaType: MediaType
    public let data: String

    public init(mediaType: MediaType, data: String) {
        self.mediaType = mediaType
        self.data = data
    }
}

public struct URLImageSourceParam: Encodable, Sendable, Equatable {
    public let type = "url"
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

public struct FileImageSourceParam: Encodable, Sendable, Equatable {
    public let type = "file"
    public let fileId: String

    public init(fileId: String) {
        self.fileId = fileId
    }
}

public enum ImageSourceParam: Sendable, Equatable {
    case base64(Base64ImageSourceParam)
    case url(URLImageSourceParam)
    case file(FileImageSourceParam)
}

extension ImageSourceParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .base64(let value): try value.encode(to: encoder)
        case .url(let value): try value.encode(to: encoder)
        case .file(let value): try value.encode(to: encoder)
        }
    }
}

public struct ImageTransformationsParam: Encodable, Sendable, Equatable {
    public enum OversizedImage: String, Encodable, Sendable, Equatable {
        case downsize
        case error
    }

    public let oversizedImage: OversizedImage?

    public init(oversizedImage: OversizedImage? = nil) {
        self.oversizedImage = oversizedImage
    }
}

public struct ImageBlockParam: Encodable, Sendable, Equatable {
    public let type = "image"
    public let source: ImageSourceParam
    public let cacheControl: CacheControlEphemeral?
    public let transformations: ImageTransformationsParam?

    public init(
        source: ImageSourceParam,
        cacheControl: CacheControlEphemeral? = nil,
        transformations: ImageTransformationsParam? = nil
    ) {
        self.source = source
        self.cacheControl = cacheControl
        self.transformations = transformations
    }
}
