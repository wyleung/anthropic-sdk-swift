/// Optimistic-concurrency precondition: the update applies only if the memory's stored
/// `contentSha256` equals the supplied value. On mismatch, the request returns a
/// `memory_precondition_failed_error` (HTTP 409); re-read the memory and retry against the fresh
/// state. If the precondition fails but the stored state already exactly matches the requested
/// `content` and `path`, the server returns 200 instead of 409. Currently the only precondition
/// kind is `content_sha256`, so this is a fixed-shape struct rather than a discriminated union --
/// same treatment as `BetaDreamOutput`. Mirrors
/// `types/beta/memory_stores/beta_managed_agents_precondition_param.py`.
public struct BetaManagedAgentsPreconditionParam: Codable, Sendable, Equatable {
    public var type: String
    public var contentSha256: String?

    public init(type: String = "content_sha256", contentSha256: String? = nil) {
        self.type = type
        self.contentSha256 = contentSha256
    }
}
