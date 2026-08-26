/// Ported from `types/beta/beta_advisor_tool_result_block.py`.
public struct BetaAdvisorToolResultBlock: Codable, Sendable, Equatable {
    public let content: BetaAdvisorToolResultContent
    public let toolUseId: String
    public let type = "advisor_tool_result"

    public init(content: BetaAdvisorToolResultContent, toolUseId: String) {
        self.content = content
        self.toolUseId = toolUseId
    }

    private enum CodingKeys: String, CodingKey {
        case content, toolUseId, type
    }
}
