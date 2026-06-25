import Foundation
import Combine
import KlineCore

/// Persisted user preferences, observable by both the popover and the status item.
final class Settings: ObservableObject {
    @Published var timeframe: Timeframe { didSet { defaults.set(timeframe.rawValue, forKey: Keys.timeframe) } }
    @Published var showCountdown: Bool { didSet { defaults.set(showCountdown, forKey: Keys.showCountdown) } }
    @Published var chimeOnClose: Bool { didSet { defaults.set(chimeOnClose, forKey: Keys.chimeOnClose) } }
    /// Binance pairs charted in the panel, in display order, e.g. ["BTCUSDT", "ETHUSDT"].
    @Published var watchedSymbols: [String] { didSet { defaults.set(watchedSymbols, forKey: Keys.watchedSymbols) } }
    /// Base tickers recently watched, most-recent-first — feeds the picker's Recent row.
    @Published var recentSymbols: [String] { didSet { defaults.set(recentSymbols, forKey: Keys.recentSymbols) } }

    private let defaults: UserDefaults

    private enum Keys {
        static let timeframe = "timeframe"
        static let showCountdown = "showCountdown"
        static let chimeOnClose = "chimeOnClose"
        static let watchedSymbols = "watchedSymbols"
        static let recentSymbols = "recentSymbols"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTimeframe = (defaults.object(forKey: Keys.timeframe) as? Int).flatMap(Timeframe.init(rawValue:))
        self.timeframe = storedTimeframe ?? .m5
        self.showCountdown = (defaults.object(forKey: Keys.showCountdown) as? Bool) ?? true
        self.chimeOnClose = (defaults.object(forKey: Keys.chimeOnClose) as? Bool) ?? false
        self.recentSymbols = defaults.stringArray(forKey: Keys.recentSymbols) ?? []
        // First run seeds BTC so the chart is visible; afterwards the stored list
        // wins, including an empty one the user cleared on purpose.
        self.watchedSymbols = defaults.object(forKey: Keys.watchedSymbols) == nil
            ? ["BTCUSDT"]
            : (defaults.stringArray(forKey: Keys.watchedSymbols) ?? [])
    }
}
