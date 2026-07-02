/// One OHLC price candle. Pure value type — the chart view and the Binance
/// decoder both speak in these, but the core never knows where they came from.
public struct Candle: Equatable {
    public let openTime: Int    // when the candle opened, epoch milliseconds — its identity
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double

    public init(openTime: Int, open: Double, high: Double, low: Double, close: Double) {
        self.openTime = openTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }

    /// True when the candle closed at or above its open (drawn lighter).
    public var isUp: Bool { close >= open }
}

public extension Array where Element == Candle {
    /// The candle that opened at `openTime` (epoch ms) — identifies a candle by
    /// when it began, not by where it sits in the window, so a caller can pick the
    /// just-closed candle without assuming the exchange has already opened the
    /// next one. `nil` if none match.
    func candle(openingAt openTime: Int) -> Candle? {
        first { $0.openTime == openTime }
    }

    /// The lowest low and highest high across the series — the vertical extent a
    /// chart must fit. `nil` for an empty series; `low == high` when flat.
    var priceRange: (low: Double, high: Double)? {
        guard let first else { return nil }
        var lo = first.low
        var hi = first.high
        for candle in dropFirst() {
            lo = Swift.min(lo, candle.low)
            hi = Swift.max(hi, candle.high)
        }
        return (lo, hi)
    }
}
