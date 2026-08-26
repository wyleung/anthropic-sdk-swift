import Anthropic

/// GA's `ContentBlock` decoder already falls back to `.unknown(type:raw:)` for any type string it
/// doesn't recognize, and every Beta-exclusive response block kind (`mcp_tool_use`,
/// `mcp_tool_result`, `advisor_tool_result`, `compaction`, `fallback`) is exactly such a case --
/// so no data is lost, it's just surfaced as raw JSON rather than through a dedicated case. This
/// is a deliberate simplification beyond a fully-parallel `BetaContentBlock` enum: see the slice-1
/// deviations note in the PR/report for the tradeoff.
public typealias BetaContentBlock = ContentBlock
