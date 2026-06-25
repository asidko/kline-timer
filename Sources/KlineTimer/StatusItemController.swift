import AppKit
import KlineCore

/// Owns the menu-bar status item: renders the glyph plus countdown, pulses red
/// in the final minute, and toggles the popover on click.
///
/// While the popover is open the menu-bar presentation is held steady: renders
/// are recorded but not applied, then re-applied on close. The item's width can
/// therefore never change while the panel is up — so the popover, anchored to
/// the item, can't be yanked by a timeframe switch, the Show-countdown toggle,
/// or the final-minute readout. The item stays at `variableLength` throughout,
/// so the glyph sits in the same spot whether the panel is open or closed.
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private lazy var normalGlyph = CandleGlyph.image(red: false)
    private lazy var redGlyph = CandleGlyph.image(red: true)
    private var pulsing = false
    private var lastRender: (timeframe: Timeframe, secondsLeft: Int, showCountdown: Bool)?

    /// Called with `true` when the panel opens and `false` when it closes, so
    /// the coin monitor can speed up or relax its refresh cadence.
    var onPanelVisibilityChange: ((Bool) -> Void)?

    // The menu-bar title fonts never change — build them once, not every tick.
    private static let regularFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    private static let semiboldFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    private static let emptyTitle = NSAttributedString()

    init(popover: NSPopover) {
        self.popover = popover
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        popover.delegate = self
        if let button = statusItem.button {
            button.wantsLayer = true
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    /// Refresh the menu-bar presentation for the current tick — unless the panel
    /// is open, in which case the state is recorded and applied on close.
    func render(timeframe: Timeframe, secondsLeft: Int, showCountdown: Bool) {
        lastRender = (timeframe, secondsLeft, showCountdown)
        guard !popover.isShown else { return }
        apply(timeframe: timeframe, secondsLeft: secondsLeft, showCountdown: showCountdown)
    }

    private func apply(timeframe: Timeframe, secondsLeft: Int, showCountdown: Bool) {
        guard let button = statusItem.button else { return }
        // "Show countdown" off means just the icon — the final-minute alert no
        // longer overrides the toggle.
        let final = showCountdown && CandleClock.isFinalMinute(timeframe: timeframe, secondsLeft: secondsLeft)
        let time = CandleClock.format(secondsLeft: secondsLeft)

        let position: NSControl.ImagePosition
        let attributedTitle: NSAttributedString
        if final {
            // Final minute: red seconds without the timeframe prefix.
            position = .imageLeading
            attributedTitle = title(" \(time)", color: .systemRed, font: Self.semiboldFont)
        } else if showCountdown {
            position = .imageLeading
            attributedTitle = title(" \(timeframe.label) · \(time)", color: .labelColor, font: Self.regularFont)
        } else {
            // Glyph only — `.imageOnly` guarantees the text is gone, regardless of prior title.
            position = .imageOnly
            attributedTitle = Self.emptyTitle
        }

        button.image = final ? redGlyph : normalGlyph
        button.imagePosition = position
        button.attributedTitle = attributedTitle
        setPulsing(final, on: button)
    }

    private func title(_ string: String, color: NSColor, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.foregroundColor: color, .font: font])
    }

    private func setPulsing(_ on: Bool, on button: NSStatusBarButton) {
        guard on != pulsing else { return }
        pulsing = on
        let key = "klinePulse"
        guard on else {
            button.layer?.removeAnimation(forKey: key)
            return
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.45
        pulse.duration = 0.55
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        button.layer?.add(pulse, forKey: key)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidShow(_ notification: Notification) {
        onPanelVisibilityChange?(true)
    }

    func popoverDidClose(_ notification: Notification) {
        // Catch the menu bar up to the state it missed while the panel was open,
        // without waiting for the next tick.
        if let last = lastRender {
            apply(timeframe: last.timeframe, secondsLeft: last.secondsLeft, showCountdown: last.showCountdown)
        }
        onPanelVisibilityChange?(false)
    }
}
