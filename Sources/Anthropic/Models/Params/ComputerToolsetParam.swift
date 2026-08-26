public struct ComputerCursorPositionConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerDoubleClickConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerHoldKeyConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerKeyConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerLeftClickConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerLeftClickDragConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerLeftMouseDownConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerLeftMouseUpConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerMiddleClickConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerMouseMoveConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerRightClickConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerScreenshotConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerScrollConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerTripleClickConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerTypeConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerWaitConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerZoomConfigParam: Encodable, Sendable, Equatable {
    public let deferLoading: Bool?
    public let enabled: Bool?

    public init(deferLoading: Bool? = nil, enabled: Bool? = nil) {
        self.deferLoading = deferLoading
        self.enabled = enabled
    }
}

public struct ComputerToolsetConfigsParam: Encodable, Sendable, Equatable {
    public let cursorPosition: ComputerCursorPositionConfigParam?
    public let doubleClick: ComputerDoubleClickConfigParam?
    public let holdKey: ComputerHoldKeyConfigParam?
    public let key: ComputerKeyConfigParam?
    public let leftClick: ComputerLeftClickConfigParam?
    public let leftClickDrag: ComputerLeftClickDragConfigParam?
    public let leftMouseDown: ComputerLeftMouseDownConfigParam?
    public let leftMouseUp: ComputerLeftMouseUpConfigParam?
    public let middleClick: ComputerMiddleClickConfigParam?
    public let mouseMove: ComputerMouseMoveConfigParam?
    public let rightClick: ComputerRightClickConfigParam?
    public let screenshot: ComputerScreenshotConfigParam?
    public let scroll: ComputerScrollConfigParam?
    public let tripleClick: ComputerTripleClickConfigParam?
    public let type: ComputerTypeConfigParam?
    public let wait: ComputerWaitConfigParam?
    public let zoom: ComputerZoomConfigParam?

    public init(
        cursorPosition: ComputerCursorPositionConfigParam? = nil,
        doubleClick: ComputerDoubleClickConfigParam? = nil,
        holdKey: ComputerHoldKeyConfigParam? = nil,
        key: ComputerKeyConfigParam? = nil,
        leftClick: ComputerLeftClickConfigParam? = nil,
        leftClickDrag: ComputerLeftClickDragConfigParam? = nil,
        leftMouseDown: ComputerLeftMouseDownConfigParam? = nil,
        leftMouseUp: ComputerLeftMouseUpConfigParam? = nil,
        middleClick: ComputerMiddleClickConfigParam? = nil,
        mouseMove: ComputerMouseMoveConfigParam? = nil,
        rightClick: ComputerRightClickConfigParam? = nil,
        screenshot: ComputerScreenshotConfigParam? = nil,
        scroll: ComputerScrollConfigParam? = nil,
        tripleClick: ComputerTripleClickConfigParam? = nil,
        type: ComputerTypeConfigParam? = nil,
        wait: ComputerWaitConfigParam? = nil,
        zoom: ComputerZoomConfigParam? = nil
    ) {
        self.cursorPosition = cursorPosition
        self.doubleClick = doubleClick
        self.holdKey = holdKey
        self.key = key
        self.leftClick = leftClick
        self.leftClickDrag = leftClickDrag
        self.leftMouseDown = leftMouseDown
        self.leftMouseUp = leftMouseUp
        self.middleClick = middleClick
        self.mouseMove = mouseMove
        self.rightClick = rightClick
        self.screenshot = screenshot
        self.scroll = scroll
        self.tripleClick = tripleClick
        self.type = type
        self.wait = wait
        self.zoom = zoom
    }
}

public struct ComputerToolset20260801Param: Encodable, Sendable, Equatable {
    public let type = "computer_toolset_20260801"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let configs: ComputerToolsetConfigsParam?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        configs: ComputerToolsetConfigsParam? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.configs = configs
    }
}
