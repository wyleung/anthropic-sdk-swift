/// One page of an id-cursor list endpoint (`SyncPage`/`AsyncPage` in the reference SDKs), used by
/// `Models.list` and `MessageBatches.list`. Paginate forward by passing `lastId` back in as
/// `afterId` on the next call; auto-iteration across pages is left to callers for now, matching
/// this port's existing "no automatic multi-page iteration yet" stance on streaming/tool-loop work.
public struct Page<Element: Decodable & Sendable>: Decodable, Sendable {
    public let data: [Element]
    public let hasMore: Bool?
    public let firstId: String?
    public let lastId: String?
}

/// One page of a token-cursor list endpoint (`SyncPageCursor`/`AsyncPageCursor` in the reference
/// SDKs), used by `Files.list`, `Skills.list`, and `Skills.Versions.list`. Paginate forward by
/// passing `nextPage` back in as the `page` query parameter on the next call.
public struct PageCursor<Element: Decodable & Sendable>: Decodable, Sendable {
    public let data: [Element]
    public let nextPage: String?
}

/// One page of a bidirectional token-cursor list endpoint (`SyncBidirectionalPageCursor`/
/// `AsyncBidirectionalPageCursor` in the reference SDKs), used only by `Sessions.list` -- every
/// other cursor-paginated Beta list endpoint (`BetaSessionResources.list`,
/// `BetaSessionThreads.list`, `Files.list`, `Skills.list`) uses the forward-only `PageCursor`
/// above. Paginate forward with `nextPage`, or backward with `prevPage`, each passed back in as
/// the `page` query parameter. `prevPage` (not `previousPage`) matches what the ambient
/// `.convertFromSnakeCase` decoding strategy actually produces from the wire's `prev_page`.
public struct BidirectionalPageCursor<Element: Decodable & Sendable>: Decodable, Sendable {
    public let data: [Element]
    public let nextPage: String?
    public let prevPage: String?
}
