import AppKit
import KlineCore

/// Owns the menu-bar status item: renders the glyph plus countdown, pulses red
/// in the final minute, and toggles the popover on click.
///
/// The item stays at `variableLength` and is never given an explicit width, so
/// the glyph sits in the same spot open or closed. While the popover is open,
/// renders are skipped entirely: changing the item's width (e.g. toggling the
/// countdown off shrinks it from text to glyph) makes NSPopover, which is
/// anchored to the item, reposition to the new width and drift off the icon. The
/// regular one-second tick catches the menu bar up right after the panel closes
/// — by then the item can resize freely with nothing anchored to it.
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private lazy var normalGlyph = CandleGlyph.image(red: false)
    private lazy var redGlyph = CandleGlyph.image(red: true)
    private var pulsing = false

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

    /// Refresh the menu-bar presentation for the current tick. Skipped while the
    /// panel is open so the item's width — and the popover anchored to it — can't
    /// move; the next tick after close catches it up.
    func render(timeframe: Timeframe, secondsLeft: Int, showCountdown: Bool) {
        guard !popover.isShown, let button = statusItem.button else { return }
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
            // A variableLength item resizes its hosting status-bar window on a
            // deferred layout pass. If the width changed since the last show
            // (e.g. the countdown was toggled off, shrinking the item), that pass
            // may not have run — so force it now. Otherwise `button.bounds` maps
            // through a stale window frame and NSPopover anchors to a garbage/empty
            // rect, landing at the screen corner. Guard the empty case too.
            button.superview?.layoutSubtreeIfNeeded()
            var anchor = button.bounds
            if anchor.isEmpty { anchor = button.frame }
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: anchor, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidShow(_ notification: Notification) {
        onPanelVisibilityChange?(true)
    }

    func popoverDidClose(_ notification: Notification) {
        onPanelVisibilityChange?(false)
    }
}
