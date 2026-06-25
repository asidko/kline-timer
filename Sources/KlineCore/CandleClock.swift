import Foundation

/// Countdown math for the current candle of a timeframe.
///
/// Candle boundaries align to the Unix epoch, which is UTC midnight — the same
/// way exchanges bucket klines: 5m candles close at :00/:05/:10, 4h candles at
/// 00:00/04:00/08:00 UTC, and so on. All supported intervals divide 86 400s
/// evenly, so epoch-modulo alignment matches the exchange boundaries exactly.
public enum CandleClock {
    /// The final-minute alert window, in seconds.
    private static let alertWindowSeconds = 60

    /// Whole seconds remaining until the current candle closes, clamped to
    /// `1...timeframe.seconds`. `now` is seconds since the Unix epoch.
    public static func secondsLeft(timeframe: Timeframe, now: TimeInterval) -> Int {
        let interval = TimeInterval(timeframe.seconds)
        let intoCandle = now.truncatingRemainder(dividingBy: interval)
        let remaining = interval - intoCandle
        return max(1, min(timeframe.seconds, Int(ceil(remaining))))
    }

    /// Index of the candle containing `now`; increments by one on every close.
    /// A change between two ticks means a candle just closed.
    public static func candleIndex(timeframe: Timeframe, now: TimeInterval) -> Int {
        Int((now / TimeInterval(timeframe.seconds)).rounded(.down))
    }

    /// Whether the candle is in its final minute — the window the UI may flag
    /// with a red readout. Only candles longer than the 60s window qualify: a 1m
    /// candle is never "final" (it would otherwise be "final" its whole life).
    public static func isFinalMinute(timeframe: Timeframe, secondsLeft: Int) -> Bool {
        secondsLeft < alertWindowSeconds && timeframe.seconds > alertWindowSeconds
    }

    /// Time string: "h:mm:ss" once an hour or more remains, otherwise "m:ss".
    public static func format(secondsLeft: Int) -> String {
        let s = secondsLeft % 60
        let m = (secondsLeft / 60) % 60
        let h = secondsLeft / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
