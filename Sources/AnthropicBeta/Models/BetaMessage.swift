import Anthropic

/// Ported from `types/beta/beta_message.py`. Reuses `BetaContainer` (= `Container`) and
/// `BetaContentBlock` (= `ContentBlock`) via their typealiases. `contextManagement` and
/// `diagnostics` are raw `JSONValue` passthroughs, matching `BetaMessageCreateParams`. `role` is
/// always `"assistant"` in the Python source (`Literal["assistant"]`), so it's fixed rather than
/// typed as `BetaRole`.
public struct BetaMessage: Codable, Sendable, Equatable {
    public let id: String
    public let type = "message"
    public let role = "assistant"
    public let content: [BetaContentBlock]
    public let model: String
    public let container: BetaContainer?
    public let contextManagement: JSONValue?
    public let diagnostics: JSONValue?
    public let stopReason: BetaStopReason?
    public let stopSequence: String?
    public let stopDetails: BetaRefusalStopDetails?
    public let usage: BetaUsage

    private enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, container
        case contextManagement, diagnostics, stopReason, stopSequence, stopDetails, usage
    }
}
