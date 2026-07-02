import CoreGraphics

/// Maps prices to vertical positions in a candle chart and back, using the same
/// top/bottom padding the chart draws with. Shared by `CandleChartView` (to place
/// ink) and `PriceLevelOverlay` (to place controls and read the cursor), so a
/// control always lands exactly on the line it represents.
struct ChartGeometry {
    static let padTop: CGFloat = 3
    static let padBottom: CGFloat = 3

    let range: (low: Double, high: Double)?
    let size: CGSize

    private var plotHeight: CGFloat { max(0, size.height - Self.padTop - Self.padBottom) }
    private var span: Double { range.map { $0.high - $0.low } ?? 0 }

    /// Vertical position of a price; the plot's vertical centre for a flat or
    /// absent range, mirroring the chart's own fallback.
    func y(_ price: Double) -> CGFloat {
        guard let range, span > 0 else { return size.height / 2 }
        return Self.padTop + CGFloat((range.high - price) / span) * plotHeight
    }

    /// Price at a vertical position, clamped to the plot so a click in the thin
    /// padding bands resolves to the nearest in-range price rather than an
    /// extrapolated one. `nil` when there is no price span to map onto.
    func price(at y: CGFloat) -> Double? {
        guard let range, span > 0, plotHeight > 0 else { return nil }
        let clamped = min(max(y, Self.padTop), Self.padTop + plotHeight)
        let fraction = Double((clamped - Self.padTop) / plotHeight)
        return range.high - fraction * span
    }
}
