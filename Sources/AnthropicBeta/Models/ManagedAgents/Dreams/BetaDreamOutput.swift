import Anthropic

/// An output memory store the dream writes consolidated memories into. Response-only -- there is
/// no params-side counterpart; the destination is chosen via `BetaOutputBehaviorParam` on create.
/// Ported from `beta_dream_output.py`.
public struct BetaDreamOutput: Codable, Sendable, Equatable {
    public let memoryStoreId: String
    public let type: String

    public init(memoryStoreId: String, type: String = "memory_store") {
        self.memoryStoreId = memoryStoreId
        self.type = type
    }
}
