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

        if let last = lastCandleIndex, index > last, settings.chimeOnClose {
            Chime.play()
        }
        lastCandleIndex = index

        timerModel.update(secondsLeft: secondsLeft)
        statusController.render(timeframe: timeframe, secondsLeft: secondsLeft, showCountdown: settings.showCountdown)
    }
}
