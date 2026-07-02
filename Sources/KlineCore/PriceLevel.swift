import Foundation

/// A horizontal price line a user drew on a coin's chart, optionally armed to
/// alert. Pure value type: it carries the alert's *configuration* (the price, the
/// armed direction, whether the bell is on) but holds no runtime crossing state —
/// `PriceAlertEngine` owns that. Stored verbatim, so it is `Codable`.
public struct PriceLevel: Codable, Identifiable, Equatable {
    /// The direction that arms the alert, fixed when the line is drawn: `.above`
    /// when the line sat above the market (waiting for a rise up to it), `.below`
    /// when it sat below (waiting for a fall down to it).
    public enum Side: String, Codable {
        case above
        case below
    }

    public let id: UUID
    public let price: Double
    public let side: Side
    public var bell: Bool

    public init(id: UUID = UUID(), price: Double, side: Side, bell: Bool = false) {
        self.id = id
        self.price = price
        self.side = side
        self.bell = bell
    }

    /// Whether `value` has reached or passed the line in the armed direction —
    /// the predicate both the live-price cross and the candle close test against.
    public func isBeyond(_ value: Double) -> Bool {
        switch side {
        case .above: return value >= price
        case .below: return value <= price
        }
    }

    /// The side to arm for a line drawn at `price` against the current `market`:
    /// a line at or above the market waits for an upward move, one below it for a
    /// downward move.
    public static func side(forLineAt price: Double, market: Double) -> Side {
        price >= market ? .above : .below
    }
}
