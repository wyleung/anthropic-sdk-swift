/// Ported from `types/beta/environments/work_stop_params.py`.
public struct BetaWorkStopParams: Encodable, Sendable, Equatable {
    /// If `true`, immediately stop work without graceful shutdown. Omitted (`nil`) defers to the
    /// server-side default of `false`.
    public var force: Bool?

    public init(force: Bool? = nil) {
        self.force = force
    }
}
