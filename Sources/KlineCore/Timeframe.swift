import Foundation

/// A trading candle interval. The raw value is the candle length in seconds.
public enum Timeframe: Int, CaseIterable, Identifiable {
    case m1 = 60
    case m3 = 180
    case m5 = 300
    case m15 = 900
    case m30 = 1800
    case h1 = 3600
    case h2 = 7200
    case h4 = 14400

    public var id: Int { rawValue }

    /// Length of one candle in seconds.
    public var seconds: Int { rawValue }

    /// Short label shown in the UI, e.g. "5m" or "4h".
    public var label: String {
        switch self {
        case .m1: return "1m"
        case .m3: return "3m"
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .h1: return "1h"
        case .h2: return "2h"
        case .h4: return "4h"
        }
    }
}
