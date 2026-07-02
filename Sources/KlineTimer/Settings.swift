import Foundation
import Combine
import KlineCore

/// Persisted user preferences, observable by both the panel and the status item.
final class Settings: ObservableObject {
    @Published var timeframe: Timeframe { didSet { defaults.set(timeframe.rawValue, forKey: Keys.timeframe) } }
    @Published var showCountdown: Bool { didSet { defaults.set(showCountdown, forKey: Keys.showCountdown) } }
    @Published var chimeOnClose: Bool { didSet { defaults.set(chimeOnClose, forKey: Keys.chimeOnClose) } }
    /// Whether the chart shows the price-level tools (draw, delete, alert bell)
    /// and the taller chart they need. Off keeps the plain, compact chart.
    @Published var drawLines: Bool { didSet { defaults.set(drawLines, forKey: Keys.drawLines) } }
    /// Binance pairs charted in the panel, in display order, e.g. ["BTCUSDT", "ETHUSDT"].
    @Published var watchedSymbols: [String] { didSet { defaults.set(watchedSymbols, forKey: Keys.watchedSymbols) } }
    /// Base tickers recently watched, most-recent-first — feeds the picker's Recent row.
    @Published var recentSymbols: [String] { didSet { defaults.set(recentSymbols, forKey: Keys.recentSymbols) } }
    /// User-drawn horizontal price levels per Binance pair. Encoded as JSON since
    /// `PriceLevel` is a struct UserDefaults can't store directly.
    @Published var priceLevels: [String: [PriceLevel]] { didSet { savePriceLevels() } }

    private let defaults: UserDefaults

    private enum Keys {
        static let timeframe = "timeframe"
        static let showCountdown = "showCountdown"
        static let chimeOnClose = "chimeOnClose"
        static let drawLines = "drawLines"
        static let watchedSymbols = "watchedSymbols"
        static let recentSymbols = "recentSymbols"
        static let priceLevels = "priceLevels"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTimeframe = (defaults.object(forKey: Keys.timeframe) as? Int).flatMap(Timeframe.init(rawValue:))
        self.timeframe = storedTimeframe ?? .m5
        self.showCountdown = (defaults.object(forKey: Keys.showCountdown) as? Bool) ?? true
        self.chimeOnClose = (defaults.object(forKey: Keys.chimeOnClose) as? Bool) ?? false
        self.drawLines = (defaults.object(forKey: Keys.drawLines) as? Bool) ?? false
        self.recentSymbols = defaults.stringArray(forKey: Keys.recentSymbols) ?? []
        self.priceLevels = Self.loadPriceLevels(defaults)
        // First run seeds BTC so the chart is visible; afterwards the stored list
        // wins, including an empty one the user cleared on purpose.
        self.watchedSymbols = defaults.object(forKey: Keys.watchedSymbols) == nil
            ? ["BTCUSDT"]
            : (defaults.stringArray(forKey: Keys.watchedSymbols) ?? [])
    }

    /// Decode the per-symbol price levels; absent or unreadable data yields none.
    private static func loadPriceLevels(_ defaults: UserDefaults) -> [String: [PriceLevel]] {
        guard let data = defaults.data(forKey: Keys.priceLevels),
              let decoded = try? JSONDecoder().decode([String: [PriceLevel]].self, from: data)
        else { return [:] }
        return decoded
    }

    private func savePriceLevels() {
        guard let data = try? JSONEncoder().encode(priceLevels) else { return }
        defaults.set(data, forKey: Keys.priceLevels)
    }
}
