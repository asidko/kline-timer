import SwiftUI
import KlineCore

/// A compact monochrome candlestick chart with a dashed line at the last close.
/// Ink comes from `Color.primary` at varying opacity, so it stays legible in
/// both light and dark menu-bar panels without hard-coded grays. User-drawn
/// price levels are the one accent: solid accent-coloured lines that read as
/// "mine" against the monochrome series.
struct CandleChartView: View {
    let candles: [Candle]
    var levels: [Double] = []

    // Bodies span ~60% of their slot; `padRight` keeps the last candle off the
    // trailing edge. Vertical padding lives in `ChartGeometry`, shared with the
    // interaction overlay so controls align to the ink.
    private let padRight: CGFloat = 2

    var body: some View {
        Canvas { context, size in draw(in: &context, size: size) }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard let range = candles.priceRange else { return }
        let geo = ChartGeometry(range: range, size: size)
        let up = Color.primary.opacity(0.30)
        let down = Color.primary.opacity(0.80)

        let slot = (size.width - padRight) / CGFloat(candles.count)
        let bodyW = max(2.4, slot * 0.6)

        for (i, candle) in candles.enumerated() {
            let cx = CGFloat(i) * slot + slot / 2
            let color = candle.isUp ? up : down
            let top = geo.y(max(candle.open, candle.close))
            let bottom = geo.y(min(candle.open, candle.close))

            // Wick as two segments — above and below the body, never behind it —
            // so the translucent body can't reveal a line running through it.
            var wick = Path()
            wick.move(to: CGPoint(x: cx, y: geo.y(candle.high)))
            wick.addLine(to: CGPoint(x: cx, y: top))
            wick.move(to: CGPoint(x: cx, y: bottom))
            wick.addLine(to: CGPoint(x: cx, y: geo.y(candle.low)))
            context.stroke(wick, with: .color(color), lineWidth: 1)

            let body = CGRect(x: cx - bodyW / 2, y: top, width: bodyW, height: max(1, bottom - top))
            context.fill(Path(roundedRect: body, cornerRadius: 0.5), with: .color(color))
        }

        let lineY = geo.y(candles[candles.count - 1].close)
        var priceLine = Path()
        priceLine.move(to: CGPoint(x: 0, y: lineY))
        priceLine.addLine(to: CGPoint(x: size.width, y: lineY))
        context.stroke(
            priceLine,
            with: .color(Color.primary.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1, dash: [2, 3])
        )

        for level in levels {
            let ly = geo.y(level)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: ly))
            line.addLine(to: CGPoint(x: size.width, y: ly))
            context.stroke(line, with: .color(Color.accentColor.opacity(0.9)), lineWidth: 1)
        }
    }
}
