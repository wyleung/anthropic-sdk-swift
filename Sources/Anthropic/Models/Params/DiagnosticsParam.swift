/// Request-level diagnostics. Supplying this opts the response into `Message.diagnostics`, which
/// explains any prompt-cache divergence from a prior request. Ported from `types/diagnostics_param.py`.
///
/// `previousMessageId` is the `id` (`msg_...`) of this client's previous `/v1/messages` response;
/// the server compares that request's prompt fingerprint against this one. Pass `nil` on the first
/// turn to opt in without a prior message to compare.
///
/// Unlike every other optional in this port, `nil` is *sent* (as JSON `null`), not omitted: the
/// key's presence is what opts in, so dropping it would silently turn diagnostics off.
public struct DiagnosticsParam: Encodable, Sendable, Equatable {
    public let previousMessageId: String?

    public init(previousMessageId: String? = nil) {
        self.previousMessageId = previousMessageId
    }

    private enum CodingKeys: String, CodingKey {
        case previousMessageId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(previousMessageId, forKey: .previousMessageId)
    }
}
