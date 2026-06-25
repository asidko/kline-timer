import SwiftUI
import KlineCore

/// A compact monochrome candlestick chart with a dashed line at the last close.
/// Ink comes from `Color.primary` at varying opacity, so it stays legible in
/// both light and dark menu-bar panels without hard-coded grays.
struct CandleChartView: View {
    let candles: [Candle]

    // Layout constants mirror the design: a little breathing room top/bottom,
    // bodies ~60% of their slot, hairline wicks.
    private let padTop: CGFloat = 3
    private let padBottom: CGFloat = 3
    private let padRight: CGFloat = 2

    var body: some View {
        Canvas { context, size in draw(in: &context, size: size) }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard let range = candles.priceRange else { return }
        let up = Color.primary.opacity(0.30)
        let down = Color.primary.opacity(0.80)

        let slot = (size.width - padRight) / CGFloat(candles.count)
        let bodyW = max(2.4, slot * 0.6)
        let span = range.high - range.low
        let plotH = size.height - padTop - padBottom
        func y(_ price: Double) -> CGFloat {
            guard span > 0 else { return size.height / 2 }
            return padTop + CGFloat((range.high - price) / span) * plotH
        }

        for (i, candle) in candles.enumerated() {
            let cx = CGFloat(i) * slot + slot / 2
            let color = candle.isUp ? up : down
            let top = y(max(candle.open, candle.close))
            let bottom = y(min(candle.open, candle.close))

            // Wick as two segments — above and below the body, never behind it —
            // so the translucent body can't reveal a line running through it.
            var wick = Path()
            wick.move(to: CGPoint(x: cx, y: y(candle.high)))
            wick.addLine(to: CGPoint(x: cx, y: top))
            wick.move(to: CGPoint(x: cx, y: bottom))
            wick.addLine(to: CGPoint(x: cx, y: y(candle.low)))
            context.stroke(wick, with: .color(color), lineWidth: 1)

            let body = CGRect(x: cx - bodyW / 2, y: top, width: bodyW, height: max(1, bottom - top))
            context.fill(Path(roundedRect: body, cornerRadius: 0.5), with: .color(color))
        }

        let lineY = y(candles[candles.count - 1].close)
        var priceLine = Path()
        priceLine.move(to: CGPoint(x: 0, y: lineY))
        priceLine.addLine(to: CGPoint(x: size.width, y: lineY))
        context.stroke(
            priceLine,
            with: .color(Color.primary.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1, dash: [2, 3])
        )
    }
}
