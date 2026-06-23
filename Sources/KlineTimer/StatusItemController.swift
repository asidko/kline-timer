import AppKit
import KlineCore

/// Owns the menu-bar status item: renders the glyph plus countdown, pulses red
/// in the final minute, and toggles the popover on click.
///
/// While the popover is open the item's width is frozen: re-renders (every
/// second, or when a toggle hides the countdown) must not resize the status
/// item, or the popover — which is anchored to it — jumps.
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private lazy var normalGlyph = CandleGlyph.image(red: false)
    private lazy var redGlyph = CandleGlyph.image(red: true)
    private var pulsing = false

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

    /// Refresh the menu-bar presentation for the current tick.
    func render(timeframe: Timeframe, secondsLeft: Int, showCountdown: Bool) {
        guard let button = statusItem.button else { return }
        let final = CandleClock.isFinalMinute(timeframe: timeframe, secondsLeft: secondsLeft)
        let time = CandleClock.format(secondsLeft: secondsLeft)

        let position: NSControl.ImagePosition
        let attributedTitle: NSAttributedString
        if final {
            // Red seconds without the timeframe prefix — shown even when the countdown is off.
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
            // Freeze the width at its current value so renders can't move the popover.
            statusItem.length = button.frame.width
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // Let the item resize to fit again; its title is already current from the last tick.
        statusItem.length = NSStatusItem.variableLength
    }
}
