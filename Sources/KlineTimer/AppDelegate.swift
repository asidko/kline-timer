import AppKit
import SwiftUI
import Combine
import KlineCore

/// Wires the one-second clock to the status item, popover, settings and chime.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let timerModel = TimerModel()
    private var statusController: StatusItemController!
    private var popover: NSPopover!
    private var ticker: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastCandleIndex: Int?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingController(rootView: PopoverView(settings: settings, timer: timerModel))
        hosting.sizingOptions = [.preferredContentSize]  // let the popover size to the SwiftUI content
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hosting
        statusController = StatusItemController(popover: popover)

        // Switching timeframe restarts the countdown immediately — and must not
        // be mistaken for a candle close, so the chime baseline is cleared.
        // `DispatchQueue.main` defers past @Published's pre-change `willSet` (so
        // `tick()` reads the committed value) while still draining in the runloop's
        // common modes — so the repaint lands immediately, not on the next tick,
        // even mid-toggle-animation. (`RunLoop.main` would stall in `.default` mode.)
        settings.$timeframe
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.lastCandleIndex = nil
                self?.tick()
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
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    @objc private func tick() {
        let now = Date().timeIntervalSince1970
        let timeframe = settings.timeframe
        let secondsLeft = CandleClock.secondsLeft(timeframe: timeframe, now: now)
        let index = CandleClock.candleIndex(timeframe: timeframe, now: now)

        if let last = lastCandleIndex, index > last, settings.chimeOnClose {
            Chime.play()
        }
        lastCandleIndex = index

        timerModel.update(secondsLeft: secondsLeft)
        statusController.render(timeframe: timeframe, secondsLeft: secondsLeft, showCountdown: settings.showCountdown)
    }
}
