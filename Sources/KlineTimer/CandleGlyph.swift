import AppKit

/// Draws the candlestick menu-bar glyph: a centred wick with a filled body.
/// The default (template) variant adapts to the menu-bar appearance; the red
/// variant marks the final minute.
enum CandleGlyph {
    static func image(red: Bool) -> NSImage {
        let s: CGFloat = 0.9  // scale the 11×16 design coordinates down to fit the bar
        let size = NSSize(width: 11 * s, height: 16 * s)
        let image = NSImage(size: size, flipped: false) { _ in
            let color: NSColor = red ? .systemRed : .black
            color.setStroke()
            color.setFill()

            // Wick spans the full height (design viewBox y=1..15, top-left origin).
            let wick = NSBezierPath()
            wick.lineWidth = 1.4 * s
            wick.lineCapStyle = .round
            wick.move(to: NSPoint(x: 5.5 * s, y: 1 * s))
            wick.line(to: NSPoint(x: 5.5 * s, y: 15 * s))
            wick.stroke()

            // Body sits over the middle of the wick (design rect 1.5,5 8×7).
            let body = NSBezierPath(
                roundedRect: NSRect(x: 1.5 * s, y: 4 * s, width: 8 * s, height: 7 * s),
                xRadius: 1.3 * s, yRadius: 1.3 * s
            )
            body.fill()
            return true
        }
        image.isTemplate = !red
        return image
    }
}
