import AppKit
import SwiftUI
import Combine
import KlineCore

/// Wires the one-second clock to the status item, panel, settings and chime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let timerModel = TimerModel()
    private lazy var coinMonitor = CoinMonitor(settings: settings)
    private let notifier: Notifier = makeNotifier()
    private lazy var alertEngine = PriceAlertEngine(notifier: notifier)
    private var statusController: StatusItemController!
    private var panelController: PanelController!
    private var ticker: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastCandleIndex: Int?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()  // one-time permission prompt when bundled; no-op for the dev path
        let hosting = NSHostingController(
            rootView: PopoverView(settings: settings, timer: timerModel, monitor: coinMonitor)
        )
        hosting.sizingOptions = [.preferredContentSize]  // PanelController tracks this to size the panel
        panelController = PanelController(content: hosting)
        statusController = StatusItemController(panel: panelController)
        // Charts poll gently in the background; faster while the panel is open.
        panelController.onVisibilityChange = { [weak self] open in
            self?.coinMonitor.setPanelOpen(open)
        }
        coinMonitor.begin()

        // Every price poll is a chance for the live price to cross a level.
        coinMonitor.$coins
            .sink { [weak self] coins in
                guard let self else { return }
                self.alertEngine.observePrices(self.snapshots(coins) { $0.price })
            }
            .store(in: &cancellables)

        // Switching timeframe restarts the countdown in the same UI pass as the
        // picker tap, so the readout's label and its number change together with
        // no one-tick frame where the new label sits above the old timeframe's
        // time. The emitted value is used directly because `@Published` fires in
        // `willSet`, before `settings.timeframe` holds the new value. The baseline
        // candle index is cleared so the restart is not read as a candle close.
        settings.$timeframe
            .dropFirst()
            .sink { [weak self] timeframe in
                self?.lastCandleIndex = nil
                self?.tick(timeframe: timeframe)
            }
            .store(in: &cancellables)

        settings.$showCountdown
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)

        startTicking()
    }

    private func startTicking() {
        tick()
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(tick as () -> Void), userInfo: nil, repeats: true)
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    @objc private func tick() {
        tick(timeframe: settings.timeframe)
    }

    private func tick(timeframe: Timeframe) {
        let now = Date().timeIntervalSince1970
        let secondsLeft = CandleClock.secondsLeft(timeframe: timeframe, now: now)
        let index = CandleClock.candleIndex(timeframe: timeframe, now: now)

        if let last = lastCandleIndex, index > last {
            // A candle just closed: a new one is now open on the exchange. The
            // candle that closed is the one before the current — its open time
            // pins it independently of how many intervals elapsed (e.g. on wake).
            if settings.chimeOnClose { Chime.play() }
            let closedOpenTimeMs = CandleClock.openTimeMs(candleIndex: index - 1, timeframe: timeframe)
            Task { [weak self] in await self?.handleCandleClose(closedOpenTimeMs: closedOpenTimeMs) }
        }
        lastCandleIndex = index

        timerModel.update(secondsLeft: secondsLeft)
        statusController.render(timeframe: timeframe, secondsLeft: secondsLeft, showCountdown: settings.showCountdown)
    }

    /// Roll the charts forward to the freshly opened candle, then judge close
    /// alerts against the real close of the candle that opened at
    /// `closedOpenTimeMs`. Done after the refresh so the candle is present, and
    /// keyed by open time so it tests the right candle even if the exchange hasn't
    /// opened the next one yet.
    private func handleCandleClose(closedOpenTimeMs: Int) async {
        await coinMonitor.refresh()
        alertEngine.observeCloses(snapshots(coinMonitor.coins) {
            $0.candles.candle(openingAt: closedOpenTimeMs)?.close
        })
    }

    /// Alert snapshots for the coins with `value` as the price under judgment,
    /// or none while Draw lines is off — the empty list also makes the engine
    /// prune its edge-tracking state, so the toggle is the alert master switch.
    private func snapshots(_ coins: [WatchedCoin], value: (WatchedCoin) -> Double?) -> [CoinAlertSnapshot] {
        guard settings.drawLines else { return [] }
        return coins.compactMap { coin in
            value(coin).map { CoinAlertSnapshot(name: coin.displayName, value: $0, levels: coin.levels) }
        }
    }
}
