/// Ported from `types/beta/environment_update_params.py`. Every field is a PATCH-merge: omitting a
/// Swift initializer argument (`nil`) leaves the outer property `nil`, which Swift's synthesized
/// `Encodable` conformance omits from the JSON body entirely (preserves the existing value
/// server-side).
public struct BetaEnvironmentUpdateParams: Encodable, Sendable, Equatable {
    public var config: BetaEnvironmentConfigParams?

    /// Tri-state: omit (`nil`) preserves the existing description; explicit `.some(nil)` clears it
    /// to null; `.some(.some(""))` stores a literal empty string (per the Python docstring: "Omit to
    /// preserve; null clears to null; an empty string is stored as an empty string"). Swift's
    /// synthesized `Encodable` composes `encodeIfPresent` with `Optional`'s own `Encodable`
    /// conformance to produce exactly these three wire states from this double-optional.
    public var description: String??

    /// Per-key tri-state without needing a double-optional: omitting the whole dictionary (`nil`)
    /// leaves all existing metadata untouched; a non-nil dictionary is sent, and within it a `nil`
    /// value deletes that key (per the Python docstring: "Set a value to null or empty string to
    /// delete the key" -- both null and "" delete, so a single-optional value is sufficient here).
    public var metadata: [String: String?]?

    public var name: String?
    public var scope: BetaEnvironmentScope?

    public init(
        config: BetaEnvironmentConfigParams? = nil,
        description: String?? = nil,
        metadata: [String: String?]? = nil,
        name: String? = nil,
        scope: BetaEnvironmentScope? = nil
    ) {
        self.config = config
        self.description = description
        self.metadata = metadata
        self.name = name
        self.scope = scope
    }
}
