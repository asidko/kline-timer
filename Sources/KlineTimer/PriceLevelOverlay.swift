import SwiftUI
import KlineCore

/// Interactive layer above a coin's candle chart for drawing horizontal price
/// levels. Hovering the chart floats a "+" at the right edge that tracks the
/// cursor, with a dashed preview line and the price it would set; a click commits
/// a level there. Each committed level shows a delete control at the left edge
/// while the chart is hovered. The committed lines themselves are drawn by
/// `CandleChartView`; this view shares its `ChartGeometry` so every control and
/// preview lands exactly on its line.
struct PriceLevelOverlay: View {
    let candles: [Candle]
    let levels: [PriceLevel]
    let rowHover: Bool
    let onAdd: (Double) -> Void
    let onRemove: (PriceLevel) -> Void
    let onToggleBell: (PriceLevel) -> Void

    @State private var hoverY: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let geo = ChartGeometry(range: candles.priceRange, size: proxy.size)
            ZStack(alignment: .topLeading) {
                // Bottom layer: the click/hover target. A delete button above it
                // consumes its own taps, so a click on empty chart adds a level
                // while a click on a delete button removes one.
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point): hoverY = point.y
                        case .ended: hoverY = nil
                        }
                    }
                    .gesture(
                        SpatialTapGesture().onEnded { tap in
                            if let price = geo.price(at: tap.location.y) { onAdd(price) }
                        }
                    )
                    // Confine adding to the candle area; the gutters are for the
                    // delete and bell controls only.
                    .padding(.horizontal, Self.gutter)

                // Delete controls and the preview follow the card's hover, so they
                // reveal whenever the row is active (as the watchlist trash does)
                // and never linger: the cursor's per-pixel position resets on its
                // own tracking area, which an NSScrollView or panel dismissal can
                // skip, but the card hover always falls back to false.
                ForEach(levels) { level in
                    levelControls(level)
                        .frame(width: proxy.size.width, height: Self.controlHeight)
                        .position(x: proxy.size.width / 2, y: clampY(geo.y(level.price), in: proxy.size))
                        .opacity(rowHover ? 1 : 0)
                        .allowsHitTesting(rowHover)
                        .animation(.easeOut(duration: 0.15), value: rowHover)
                }

                // Suppress the add-preview while the cursor sits in an existing
                // level's control band: that row belongs to its delete/bell
                // buttons, and a "+" there can't add a line the dedup would reject
                // anyway — showing it only invites a click that hits the bell.
                if rowHover, let y = hoverY, let price = geo.price(at: y),
                   !isNearLevel(y, geo: geo) {
                    PreviewLine(price: price, width: proxy.size.width)
                        .position(x: proxy.size.width / 2, y: y)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: rowHover) { hovering in
                if !hovering { hoverY = nil }
            }
        }
    }

    private static let controlHeight: CGFloat = 18
    /// Left/right gutter the chart is inset by, so the delete and bell controls
    /// sit beside the candles rather than over them. Shared with the chart's own
    /// horizontal padding so the two stay aligned.
    static let gutter: CGFloat = 20
    /// Fixed slot every control glyph (delete, bell, the preview "+") sits in, so
    /// the committed and preview rows line their price up at the same x and the
    /// "+" lands in the bell's column.
    static let iconWidth: CGFloat = 16

    /// A level's controls at its line: delete + price tag in the left gutter, the
    /// alert bell in the right gutter. The spacer between them is inert, so a click
    /// there falls through to the add-level target beneath.
    private func levelControls(_ level: PriceLevel) -> some View {
        HStack(spacing: 0) {
            DeleteLevelButton(price: level.price) { onRemove(level) }
            Spacer(minLength: 0)
            BellToggle(on: level.bell) { onToggleBell(level) }
        }
        .padding(.horizontal, 4)
    }

    /// Keep a control on screen even when its price has drifted out of the
    /// candles' current range, so it stays removable.
    private func clampY(_ y: CGFloat, in size: CGSize) -> CGFloat {
        min(max(y, Self.controlHeight / 2), size.height - Self.controlHeight / 2)
    }

    /// Whether `y` falls within a committed level's control band — the rows the
    /// delete/bell buttons occupy.
    private func isNearLevel(_ y: CGFloat, geo: ChartGeometry) -> Bool {
        levels.contains { abs(geo.y($0.price) - y) < Self.controlHeight / 2 }
    }
}

/// The left-edge control for one committed level: a delete glyph that reddens on
/// hover, with the level's price beside it.
private struct DeleteLevelButton: View {
    let price: Double
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(hover ? Color.red : Color.secondary)
                    .frame(width: PriceLevelOverlay.iconWidth)
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help("Remove price level")

            Text(PriceFormat.string(price))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// The right-edge alert toggle for one committed level: a bell that fills in the
/// accent when armed, so a glance tells which levels will notify on a crossing.
private struct BellToggle: View {
    let on: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: on ? "bell.fill" : "bell")
                .font(.system(size: 11))
                .foregroundStyle(on ? Color.accentColor : (hover ? Color.primary : Color.secondary))
                .frame(width: PriceLevelOverlay.iconWidth)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(on ? "Alerting on cross — click to mute" : "Alert when price crosses this level")
    }
}

/// The transient line shown while hovering: a dashed accent rule across the chart
/// with the candidate price tagged at its left edge — where committed lines show
/// theirs — and a "+" pinned to the right. The caller sizes it to the candle area
/// and positions it at the cursor.
private struct PreviewLine: View {
    let price: Double
    let width: CGFloat

    var body: some View {
        ZStack {
            HLine()
                .stroke(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(height: 1)
                .padding(.horizontal, PriceLevelOverlay.gutter)  // rule spans the candle area, like committed lines

            HStack(spacing: 4) {
                // Reserve the delete column so the candidate price lines up with a
                // committed level's price rather than sitting further left.
                Color.clear.frame(width: PriceLevelOverlay.iconWidth, height: PriceLevelOverlay.iconWidth)
                Text(PriceFormat.string(price))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: PriceLevelOverlay.iconWidth)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: width)
    }
}

/// A horizontal line across the middle of its rect — the preview's rule.
private struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
