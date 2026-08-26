public struct CacheControlEphemeral: Encodable, Sendable, Equatable {
    public enum TTL: String, Encodable, Sendable, Equatable {
        case fiveMinutes = "5m"
        case oneHour = "1h"
    }

    public let type = "ephemeral"
    public let ttl: TTL?

    public init(ttl: TTL? = nil) {
        self.ttl = ttl
    }
}
