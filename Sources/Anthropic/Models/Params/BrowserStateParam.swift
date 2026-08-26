public struct ToolReferenceBlockParam: Encodable, Sendable, Equatable {
    public let type = "tool_reference"
    public let toolName: String
    public let cacheControl: CacheControlEphemeral?

    public init(toolName: String, cacheControl: CacheControlEphemeral? = nil) {
        self.toolName = toolName
        self.cacheControl = cacheControl
    }
}

public struct BrowserStateTabEntryParam: Encodable, Sendable, Equatable {
    public let tabId: String
    public let title: String
    public let url: String
    public let active: Bool?

    public init(tabId: String, title: String, url: String, active: Bool? = nil) {
        self.tabId = tabId
        self.title = title
        self.url = url
        self.active = active
    }
}

public struct BrowserStateChangeTabOpenedParam: Encodable, Sendable, Equatable {
    public let type = "tab_opened"
    public let tabId: String

    public init(tabId: String) {
        self.tabId = tabId
    }
}

public struct BrowserStateChangeDownloadStartedParam: Encodable, Sendable, Equatable {
    public let type = "download_started"
    public let downloadId: String
    public let url: String

    public init(downloadId: String, url: String) {
        self.downloadId = downloadId
        self.url = url
    }
}

public struct BrowserStateChangeDownloadCompletedParam: Encodable, Sendable, Equatable {
    public let type = "download_completed"
    public let downloadId: String
    public let url: String
    public let path: String?
    public let sizeBytes: Int?

    public init(downloadId: String, url: String, path: String? = nil, sizeBytes: Int? = nil) {
        self.downloadId = downloadId
        self.url = url
        self.path = path
        self.sizeBytes = sizeBytes
    }
}

public struct BrowserStateChangeDownloadFailedParam: Encodable, Sendable, Equatable {
    public let type = "download_failed"
    public let downloadId: String
    public let url: String
    public let error: String?

    public init(downloadId: String, url: String, error: String? = nil) {
        self.downloadId = downloadId
        self.url = url
        self.error = error
    }
}

public enum BrowserStateChangeParam: Sendable, Equatable {
    case tabOpened(BrowserStateChangeTabOpenedParam)
    case downloadStarted(BrowserStateChangeDownloadStartedParam)
    case downloadCompleted(BrowserStateChangeDownloadCompletedParam)
    case downloadFailed(BrowserStateChangeDownloadFailedParam)
}

extension BrowserStateChangeParam: Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .tabOpened(let value): try value.encode(to: encoder)
        case .downloadStarted(let value): try value.encode(to: encoder)
        case .downloadCompleted(let value): try value.encode(to: encoder)
        case .downloadFailed(let value): try value.encode(to: encoder)
        }
    }
}

public struct BrowserStateBlockParam: Encodable, Sendable, Equatable {
    public let type = "browser_state"
    public let tabs: [BrowserStateTabEntryParam]
    public let cacheControl: CacheControlEphemeral?
    public let stateChanges: [BrowserStateChangeParam]?

    public init(
        tabs: [BrowserStateTabEntryParam],
        cacheControl: CacheControlEphemeral? = nil,
        stateChanges: [BrowserStateChangeParam]? = nil
    ) {
        self.tabs = tabs
        self.cacheControl = cacheControl
        self.stateChanges = stateChanges
    }
}
