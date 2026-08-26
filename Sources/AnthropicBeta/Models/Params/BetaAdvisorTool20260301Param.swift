import Anthropic

/// Ported from `types/beta/beta_advisor_tool_20260301_param.py`. `model` follows GA's convention of
/// plain `String` for model identifiers. `allowedCallers` reuses GA's existing `AllowedCaller`
/// (confirmed field-identical: `direct`/`code_execution_20250825`/`code_execution_20260120`/
/// `code_execution_20260521`). `cacheControl` and `caching` are distinct fields despite sharing a
/// type -- the former caches this tool-use block, the latter caches the advisor's own prompt.
public struct BetaAdvisorTool20260301Param: Encodable, Sendable, Equatable {
    public let model: String
    public let name = "advisor"
    public let type = "advisor_20260301"
    public let allowedCallers: [AllowedCaller]?
    public let cacheControl: CacheControlEphemeral?
    public let caching: CacheControlEphemeral?
    public let deferLoading: Bool?
    public let maxTokens: Int?
    public let maxUses: Int?
    public let strict: Bool?

    public init(
        model: String,
        allowedCallers: [AllowedCaller]? = nil,
        cacheControl: CacheControlEphemeral? = nil,
        caching: CacheControlEphemeral? = nil,
        deferLoading: Bool? = nil,
        maxTokens: Int? = nil,
        maxUses: Int? = nil,
        strict: Bool? = nil
    ) {
        self.model = model
        self.allowedCallers = allowedCallers
        self.cacheControl = cacheControl
        self.caching = caching
        self.deferLoading = deferLoading
        self.maxTokens = maxTokens
        self.maxUses = maxUses
        self.strict = strict
    }
}
