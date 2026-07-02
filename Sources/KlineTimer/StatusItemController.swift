import AppKit
import KlineCore

/// Owns the menu-bar status item: renders the glyph plus countdown, pulses red
/// in the final minute, and toggles the panel on click.
///
/// The item stays at `variableLength`; the countdown text changes its width as
/// it ticks. Measured behaviour: a width change keeps the item's TRAILING
/// (right) edge fixed and grows it to the left. The glyph is therefore drawn on
/// the trailing edge, giving the panel a stable point to hang from however the
/// text grows or shrinks — the positioning itself lives in `PanelController`.
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: PanelController
    private lazy var normalGlyph = CandleGlyph.image(red: false)
    private lazy var redGlyph = CandleGlyph.image(red: true)
    private var pulsing = false

    // The menu-bar title fonts never change — build them once, not every tick.
    private static let regularFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    private static let semiboldFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    private static let emptyTitle = NSAttributedString()

    init(panel: PanelController) {
        self.panel = panel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.wantsLayer = true
            button.target = self
            button.action = #selector(togglePanel)
        }
    }

    /// Refresh the menu-bar presentation for the current tick.
    func render(timeframe: Timeframe, secondsLeft: Int, showCountdown: Bool) {
        guard let button = statusItem.button else { return }
        // "Show countdown" off means just the icon — the final-minute alert no
        // longer overrides the toggle.
        let final = showCountdown && CandleClock.isFinalMinute(timeframe: timeframe, secondsLeft: secondsLeft)
        let time = CandleClock.format(secondsLeft: secondsLeft)

        // The glyph trails the text so it stays pinned to the item's stable
        // trailing edge as the text resizes (see the type doc). The trailing
        // space in the titles sets it off from the time; `.imageOnly`
        // guarantees the text is gone regardless of prior title.
        let attributedTitle: NSAttributedString
        if !showCountdown {
            attributedTitle = Self.emptyTitle
        } else if final {
            // Final minute: red seconds without the timeframe prefix.
            attributedTitle = title("\(time) ", color: .systemRed, font: Self.semiboldFont)
        } else {
            attributedTitle = title("\(timeframe.label) · \(time) ", color: .labelColor, font: Self.regularFont)
        }

        button.image = final ? redGlyph : normalGlyph
        button.imagePosition = showCountdown ? .imageTrailing : .imageOnly
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

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panel.toggle(from: button)
    }
}
