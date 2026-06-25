import Foundation
import Combine
import KlineCore

/// A coin charted in the panel: its Binance pair, a friendly label, and the most
/// recent candles/price (or a `failed` flag when the last fetch errored).
struct WatchedCoin: Identifiable {
    let symbol: String          // full Binance pair, e.g. "BTCUSDT"
    let displayName: String     // header label, e.g. "BTC"
    var candles: [Candle] = []
    var price: Double?
    var failed = false
    var id: String { symbol }
}

/// Live candle data for the watched coins on the active timeframe. Polls
/// continuously once started: gently in the background, faster while the panel
/// is open so the charts feel live.
@MainActor
final class CoinMonitor: ObservableObject {
    @Published private(set) var coins: [WatchedCoin] = []

    private let settings: Settings
    private var pollTimer: Timer?
    private var cancellable: AnyCancellable?

    private static let candleCount = 10
    /// Refresh cadence: snappy while the user watches the panel, gentle in the
    /// background so prices are already warm the next time it opens.
    private static let openInterval: TimeInterval = 2
    private static let idleInterval: TimeInterval = 10
    // More than the picker shows (3), so filtering out already-watched coins still leaves recents.
    private static let maxRecents = 12

    init(settings: Settings) {
        self.settings = settings
        // A new timeframe means new candles; repaint the charts when one lands.
        cancellable = settings.$timeframe
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refresh() } }
    }

    // MARK: Polling lifecycle

    /// Begin background polling at the idle cadence (called once at launch).
    func begin() {
        rebuildFromSettings()
        Task { await refresh() }
        schedule(every: Self.idleInterval)
    }

    /// Switch cadence as the panel opens (fast) or closes (idle). Opening also
    /// refreshes at once so the charts are current the instant they appear.
    func setPanelOpen(_ open: Bool) {
        schedule(every: open ? Self.openInterval : Self.idleInterval)
        if open { Task { await refresh() } }
    }

    private func schedule(every interval: TimeInterval) {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    // MARK: Mutations

    /// Add a coin picked from the catalog (its base ticker, e.g. "ETH") to the
    /// bottom of the list and record it in recents. Already-watched is a no-op.
    func add(_ base: String) {
        guard let symbol = Self.normalize(base) else { return }
        let name = Self.display(symbol)
        pushRecent(name)
        guard !coins.contains(where: { $0.symbol == symbol }) else { return }
        coins.append(WatchedCoin(symbol: symbol, displayName: name))
        settings.watchedSymbols = coins.map(\.symbol)
        refreshNow()
    }

    func remove(_ symbol: String) {
        coins.removeAll { $0.symbol == symbol }
        settings.watchedSymbols = coins.map(\.symbol)
    }

    // MARK: Fetch

    /// Refresh now — used when a candle just closed so the charts roll forward
    /// to the freshly opened candle without waiting for the next poll tick.
    func refreshNow() { Task { await refresh() } }

    /// Binance's klines endpoint is single-symbol (no `symbols=[…]` batch — that
    /// exists only on the ticker endpoints), so each coin is its own request;
    /// firing them concurrently keeps a multi-coin refresh as fast as one.
    private func refresh() async {
        let interval = settings.timeframe.label
        let symbols = coins.map(\.symbol)
        await withTaskGroup(of: (String, [Candle]?).self) { group in
            for symbol in symbols {
                group.addTask {
                    (symbol, try? await BinanceClient.klines(
                        symbol: symbol, interval: interval, limit: Self.candleCount))
                }
            }
            for await (symbol, candles) in group { apply(symbol: symbol, candles: candles) }
        }
    }

    private func apply(symbol: String, candles: [Candle]?) {
        guard let index = coins.firstIndex(where: { $0.symbol == symbol }) else { return }
        if let candles, !candles.isEmpty {
            coins[index].candles = candles
            coins[index].price = candles.last?.close
            coins[index].failed = false
        } else {
            coins[index].failed = true
        }
    }

    /// Reconcile the live list with the persisted symbols, preserving already
    /// fetched candles and the user's ordering.
    private func rebuildFromSettings() {
        let symbols = settings.watchedSymbols
        coins.removeAll { !symbols.contains($0.symbol) }
        for symbol in symbols where !coins.contains(where: { $0.symbol == symbol }) {
            coins.append(WatchedCoin(symbol: symbol, displayName: Self.display(symbol)))
        }
        coins.sort {
            (symbols.firstIndex(of: $0.symbol) ?? 0) < (symbols.firstIndex(of: $1.symbol) ?? 0)
        }
    }

    private func pushRecent(_ base: String) {
        var recents = settings.recentSymbols.filter { $0 != base }
        recents.insert(base, at: 0)
        settings.recentSymbols = Array(recents.prefix(Self.maxRecents))
    }

    // MARK: Symbol shaping

    /// Letters/digits only, upper-cased; a bare base like "eth" becomes the USDT
    /// pair traders mean. Returns nil for empty input.
    static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !cleaned.isEmpty else { return nil }
        let quotes = ["USDT", "USDC", "BUSD", "FDUSD", "BTC", "ETH"]
        if quotes.contains(where: { cleaned.hasSuffix($0) && cleaned.count > $0.count }) {
            return cleaned
        }
        return cleaned + "USDT"
    }

    /// The pair without its dollar quote, for the header ("BTCUSDT" → "BTC").
    static func display(_ symbol: String) -> String {
        for quote in ["USDT", "USDC", "BUSD", "FDUSD"] where symbol.hasSuffix(quote) && symbol.count > quote.count {
            return String(symbol.dropLast(quote.count))
        }
        return symbol
    }
}
