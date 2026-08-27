/// Ported from `types/beta/beta_packages_params.py`. Every field is optional here (unlike the
/// response-side `BetaPackages`, where every list field is non-optional) -- omitting a field on
/// create/update leaves that package manager's list untouched.
public struct BetaPackagesParams: Encodable, Sendable, Equatable {
    public var apt: [String]?
    public var cargo: [String]?
    public var gem: [String]?
    public var go: [String]?
    public var npm: [String]?
    public var pip: [String]?
    public var type: String?

    public init(
        apt: [String]? = nil,
        cargo: [String]? = nil,
        gem: [String]? = nil,
        go: [String]? = nil,
        npm: [String]? = nil,
        pip: [String]? = nil,
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
