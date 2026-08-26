/// Ported from `beta_message_param.py`'s `role` literal. Adds `.system` beyond GA's `Role`, so
/// this duplicates the type rather than reusing it.
public enum BetaRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
    case system
}
