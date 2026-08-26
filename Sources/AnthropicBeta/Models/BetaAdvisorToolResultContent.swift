/// Ported from the `Content` type alias in `types/beta/beta_advisor_tool_result_block.py` (and its
/// param-side twin in `beta_advisor_tool_result_block_param.py`, which unions the same three shapes).
/// Since `BetaAdvisorToolResultError`/`BetaAdvisorResultBlock`/`BetaAdvisorRedactedResultBlock` are
/// themselves shared response/param types (each field-identical with no `cache_control` on either
/// side), this union is fully `Codable` and serves both `BetaAdvisorToolResultBlock` and
/// `BetaAdvisorToolResultBlockParam` -- no separate `...Param` union is needed.
public enum BetaAdvisorToolResultContent: Sendable, Equatable {
    case error(BetaAdvisorToolResultError)
    case result(BetaAdvisorResultBlock)
    case redactedResult(BetaAdvisorRedactedResultBlock)
}

extension BetaAdvisorToolResultContent: Codable {
    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try discriminator.decode(String.self, forKey: .type)
        switch type {
        case "advisor_tool_result_error": self = .error(try BetaAdvisorToolResultError(from: decoder))
        case "advisor_result": self = .result(try BetaAdvisorResultBlock(from: decoder))
        case "advisor_redacted_result": self = .redactedResult(try BetaAdvisorRedactedResultBlock(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: discriminator,
                debugDescription: "Unrecognized BetaAdvisorToolResultContent type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .error(let value): try value.encode(to: encoder)
        case .result(let value): try value.encode(to: encoder)
        case .redactedResult(let value): try value.encode(to: encoder)
        }
    }
}
