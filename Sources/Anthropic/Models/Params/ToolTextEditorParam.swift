public struct ToolTextEditor20250124Param: Encodable, Sendable, Equatable {
    public let name = "str_replace_editor"
    public let type = "text_editor_20250124"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let inputExamples: [JSONValue]?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        inputExamples: [JSONValue]? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.inputExamples = inputExamples
        self.strict = strict
    }
}

public struct ToolTextEditor20250429Param: Encodable, Sendable, Equatable {
    public let name = "str_replace_based_edit_tool"
    public let type = "text_editor_20250429"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let inputExamples: [JSONValue]?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        inputExamples: [JSONValue]? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.inputExamples = inputExamples
        self.strict = strict
    }
}

public struct ToolTextEditor20250728Param: Encodable, Sendable, Equatable {
    public let name = "str_replace_based_edit_tool"
    public let type = "text_editor_20250728"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let inputExamples: [JSONValue]?
    public let maxCharacters: Int?
    public let strict: Bool?

    public init(
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        inputExamples: [JSONValue]? = nil,
        maxCharacters: Int? = nil,
        strict: Bool? = nil
    ) {
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.deferLoading = deferLoading
        self.inputExamples = inputExamples
        self.maxCharacters = maxCharacters
        self.strict = strict
    }
}
