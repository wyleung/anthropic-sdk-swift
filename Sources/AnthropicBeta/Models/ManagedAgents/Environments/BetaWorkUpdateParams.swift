/// Ported from `types/beta/environments/work_update_params.py`. `metadata` is a required patch (not
/// omittable) whose per-key values are individually tri-state: a string upserts that key, `nil`
/// deletes it -- matching the "Set a key to a string to upsert it, or to null to delete it" Python
/// docstring.
public struct BetaWorkUpdateParams: Encodable, Sendable, Equatable {
    public var metadata: [String: String?]

    public init(metadata: [String: String?]) {
        self.metadata = metadata
    }
}
