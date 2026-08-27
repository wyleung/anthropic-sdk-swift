import Anthropic

/// Ported from `beta_currency.py` (`Literal["USD"]`). `USD` is the only currency currently
/// supported; the accepted set is closed and grows only when a new currency is priced. Modeled as
/// a small closed set with a forward-compat fallback, mirroring `BetaManagedAgentsModelSpeed`'s
/// bare-string `Codable` pattern.
public enum BetaCurrency: Sendable, Equatable {
    case usd
    case unknown(String)
}

extension BetaCurrency: Codable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "USD": self = .usd
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .usd: try container.encode("USD")
        case .unknown(let value): try container.encode(value)
        }
    }
}

/// A monetary amount in a specific currency, as returned in session budget/usage responses.
/// Ported from `beta_monetary_amount.py`. `amount` is minor units of the currency as an integer
/// decimal string (e.g. `"2500"` is $25.00) so no float rounding is ever applied.
public struct BetaMonetaryAmount: Codable, Sendable, Equatable {
    public let amount: String
    public let currency: BetaCurrency

    public init(amount: String, currency: BetaCurrency) {
        self.amount = amount
        self.currency = currency
    }
}

/// Request-side counterpart to `BetaMonetaryAmount`. Ported from `beta_monetary_amount_param.py`
/// (byte-identical shape to the response side).
public struct BetaMonetaryAmountParams: Encodable, Sendable, Equatable {
    public let amount: String
    public let currency: BetaCurrency

    public init(amount: String, currency: BetaCurrency) {
        self.amount = amount
        self.currency = currency
    }
}
