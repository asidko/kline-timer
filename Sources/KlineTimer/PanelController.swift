import AppKit
import SwiftUI

/// Presents the app panel in a borderless floating window positioned with
/// explicit geometry under the status-item glyph.
///
/// NSPopover ties its position to a live view inside the status item, whose
/// width changes every tick (the countdown text) and whose host window
/// relayouts on deferred passes — the drift and the misaligned arrow came from
/// re-anchoring through that churn. This window is placed once per open from
/// the item's stable trailing edge and only resizes in place when the SwiftUI
/// content changes, so it cannot wander. There is no arrow: the panel hangs
/// under the icon like a menu.
///
/// Transient behaviour matches NSPopover: it closes on a click outside the
/// app, on Escape (unless the content handles it, e.g. the coin picker's
/// `onExitCommand`), on losing key status, and on the status-item toggle.
final class PanelController: NSObject, NSWindowDelegate {
    /// `true` when the panel opens and `false` when it closes, so the coin
    /// monitor can speed up or relax its refresh cadence.
    var onVisibilityChange: ((Bool) -> Void)?

    private let panel: DismissablePanel
    private let content: NSViewController
    private var sizeObservation: NSKeyValueObservation?
    private var clickMonitor: Any?
    /// Geometry captured at open — the glyph's screen X, the menu bar's bottom
    /// edge, and the screen to clamp against. Content size changes re-lay out
    /// against this fixed point, so the panel never moves while shown.
    private var anchor: (glyphCenterX: CGFloat, top: CGFloat, screen: NSScreen)?

    private static let cornerRadius: CGFloat = 12
    private static let menuBarGap: CGFloat = 4
    private static let screenMargin: CGFloat = 8

    /// When a status-item click reaches the button action, the click itself may
    /// already have closed the panel via `windowDidResignKey` (AppKit-version
    /// dependent). A toggle arriving this soon after a close is that same
    /// click — it means "dismiss", not "reopen".
    private static let reopenSuppression: TimeInterval = 0.2
    private var lastCloseAt: TimeInterval = -1

    init(content: NSViewController) {
        self.content = content
        // Non-activating: the panel takes key events (picker text field, ⌘Q)
        // without activating the app or stealing focus from the frontmost app.
        panel = DismissablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }

        // The popover material chrome NSPopover used to provide, rounded via
        // maskImage so the vibrancy itself is clipped, not just the sublayers.
        let chrome = NSVisualEffectView()
        chrome.material = .popover
        chrome.state = .active
        chrome.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        content.view.frame = chrome.bounds
        content.view.autoresizingMask = [.width, .height]
        chrome.addSubview(content.view)
        panel.contentView = chrome

        // The hosting controller publishes its SwiftUI ideal size here (see
        // `sizingOptions` at the call site); the panel tracks it in place.
        sizeObservation = content.observe(\.preferredContentSize) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self, self.panel.isVisible else { return }
                self.layout()
            }
        }
    }

    func toggle(from button: NSStatusBarButton) {
        if panel.isVisible {
            close()
        } else if ProcessInfo.processInfo.systemUptime - lastCloseAt > Self.reopenSuppression {
            show(from: button, attempt: 0)
        }
    }

    func close() {
        guard panel.isVisible else { return }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        anchor = nil
        lastCloseAt = ProcessInfo.processInfo.systemUptime
        panel.orderOut(nil)
        onVisibilityChange?(false)
    }

    /// Place and show the panel once the status window's frame is a sane
    /// on-screen rect. A width change resizes that window on a deferred pass,
    /// during which the frame is momentarily degenerate (zero height or a
    /// screen corner); reading it then would misplace the panel, so let the
    /// pending layout settle and retry on the next runloop — a few hops at most.
    private func show(from button: NSStatusBarButton, attempt: Int) {
        // A retry queued by an earlier click may land after a newer click has
        // already shown the panel; running it would re-anchor and double up
        // the click monitor.
        guard !panel.isVisible else { return }
        guard let window = button.window, window.frame.height > 10, let screen = window.screen else {
            if attempt < 3 {
                DispatchQueue.main.async { [weak self] in
                    self?.show(from: button, attempt: attempt + 1)
                }
            } else {
                NSLog("PanelController: status window frame never settled; skipping open")
            }
            return
        }
        anchor = (glyphCenterX: Self.glyphScreenCenterX(of: button, in: window),
                  top: window.frame.minY - Self.menuBarGap,
                  screen: screen)
        layout()
        panel.makeKeyAndOrderFront(nil)
        // A click delivered to any other app closes the panel. This app's own
        // events (the panel, the status item) never reach a global monitor.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.close()
        }
        onVisibilityChange?(true)
    }

    /// Center the panel under the glyph, clamped to the screen, top edge held
    /// at the menu bar so content growth extends downward.
    private func layout() {
        guard let anchor else { return }
        var size = content.preferredContentSize
        if size.width <= 1 || size.height <= 1 { size = content.view.fittingSize }
        let visible = anchor.screen.visibleFrame
        // Never extend past the bottom of the screen (or under the Dock).
        size.height = min(size.height, anchor.top - visible.minY - Self.screenMargin)
        let x = min(max(anchor.glyphCenterX - size.width / 2, visible.minX + Self.screenMargin),
                    visible.maxX - Self.screenMargin - size.width)
        let frame = NSRect(x: x, y: anchor.top - size.height, width: size.width, height: size.height)
        // KVO fires on every preferredContentSize set, changed or not — skip the
        // display + shadow pass when the frame is already right.
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    /// Screen X of the glyph's center, measured from the button's own layout —
    /// not a hard-coded slot width — so panel centering survives glyph art,
    /// system padding, image-position, and locale changes.
    private static func glyphScreenCenterX(of button: NSStatusBarButton, in window: NSWindow) -> CGFloat {
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? .zero
        let local = imageRect.isEmpty ? button.bounds : imageRect
        return window.convertToScreen(button.convert(local, to: nil)).midX
    }

    /// Losing key status means the user moved on (activated another app,
    /// switched space) — transient panels don't outlive that.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    /// A stretchable rounded-rect alpha mask for NSVisualEffectView — the
    /// supported way to round vibrancy without clipping artifacts.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.set()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// A borderless panel that can become key (borderless windows refuse by
/// default) and reports Escape once the content's responder chain declines it.
private final class DismissablePanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
