/// Ported from `types/beta/beta_packages.py`. Every package-list field is non-optional here
/// (an environment with no `pip` packages reports `pip: []`, not `nil`) -- unlike the params-side
/// `BetaPackagesParams`, where every field is optional. Response/param optionality is asymmetric;
/// confirmed by reading both files rather than assumed from family resemblance.
public struct BetaPackages: Codable, Sendable, Equatable {
    public let apt: [String]
    public let cargo: [String]
    public let gem: [String]
    public let go: [String]
    public let npm: [String]
    public let pip: [String]
    public let type: String?

    public init(
        apt: [String], cargo: [String], gem: [String], go: [String], npm: [String], pip: [String],
        type: String? = nil
    ) {
        self.apt = apt
        self.cargo = cargo
        self.gem = gem
        self.go = go
        self.npm = npm
        self.pip = pip
        self.type = type
    }
}
