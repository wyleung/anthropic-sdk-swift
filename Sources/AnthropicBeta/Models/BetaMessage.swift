import Anthropic

/// Ported from `types/beta/beta_message.py`. Reuses `BetaContainer` (= `Container`) and
/// `BetaContentBlock` (= `ContentBlock`) via their typealiases. `contextManagement` is a raw
/// `JSONValue` passthrough, matching `BetaMessageCreateParams`; `diagnostics` reuses GA's `Diagnostics`
/// (Python's `BetaDiagnostics` and its six cache-miss variants are field-identical). `role` is
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
    public let diagnostics: Diagnostics?
    /// What the API changed about the request's input before showing it to the model, and blocks that
    /// failed a binding check but were left in place -- one entry per block, in request order. Needs
    /// `anthropic-beta: thinking-binding-controls-2026-08-01`; `[]` when there is nothing to report.
    /// When streaming it is final in `message_start`; a `message_delta` carries it only after a
    /// mid-stream model fallback, in which case it replaces the `message_start` value.
    public let inputTransformations: [BetaInputTransformation]?
    public let stopReason: BetaStopReason?
    public let stopSequence: String?
    public let stopDetails: BetaRefusalStopDetails?
    public let usage: BetaUsage

    private enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, container
        case contextManagement, diagnostics, inputTransformations, stopReason, stopSequence, stopDetails, usage
    }
}
