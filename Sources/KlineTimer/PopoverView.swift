import SwiftUI
import AppKit
import KlineCore

/// The panel content: countdown readout, timeframe picker, the watched-coin
/// chart, toggles and quit. The Watch-coin button opens a spotlight-style
/// picker that replaces the panel until a coin is chosen or it's dismissed.
struct PopoverView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var timer: TimerModel
    @ObservedObject var monitor: CoinMonitor

    @State private var showPicker = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    private var timeString: String { CandleClock.format(secondsLeft: timer.secondsLeft) }
    private var isFinalMinute: Bool {
        CandleClock.isFinalMinute(timeframe: settings.timeframe, secondsLeft: timer.secondsLeft)
    }

    var body: some View {
        Group {
            if showPicker {
                CoinPickerView(monitor: monitor, settings: settings, onClose: { showPicker = false })
            } else {
                panel
            }
        }
        .frame(width: 288)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            readout
            Divider()
            VStack(spacing: 0) {
                timeframePicker
                watchCoinButton
            }
            if !monitor.coins.isEmpty {
                Divider()
                coinsScroller
            }
            Divider()
            toggles
            Divider()
            quit
        }
    }

    // MARK: Watched coins

    private static let visibleCoinRows: CGFloat = 2

    /// The watched coins, scrollable once past the second so the panel never
    /// grows taller than two charts no matter how many coins are added. The cap
    /// derives from `CoinRowView.rowHeight`, so it tracks the row's own layout.
    private var coinsScroller: some View {
        let count = CGFloat(monitor.coins.count)
        let content = count * CoinRowView.rowHeight + max(0, count - 1)  // rows + inner dividers
        let cap = Self.visibleCoinRows * CoinRowView.rowHeight + 1
        return OverlayScroll {
            VStack(spacing: 0) {
                ForEach(Array(monitor.coins.enumerated()), id: \.element.id) { index, coin in
                    if index > 0 { Divider() }
                    CoinRowView(
                        coin: coin,
                        drawLines: settings.drawLines,
                        onRemove: { monitor.remove(coin.symbol) },
                        onAddLevel: { monitor.addLevel(coin.symbol, price: $0) },
                        onRemoveLevel: { monitor.removeLevel(coin.symbol, id: $0.id) },
                        onToggleBell: { monitor.setBell(coin.symbol, id: $0.id, on: !$0.bell) }
                    )
                }
            }
        }
        .frame(height: min(content, cap))
    }

    // MARK: Readout

    private var readout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Next \(settings.timeframe.label) close").tagStyle()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(timeString)
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isFinalMinute ? Color.red : Color.primary)
                Text("left")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: Timeframe

    private var timeframePicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Timeframe").tagStyle()
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Timeframe.allCases) { tf in
                    let selected = settings.timeframe == tf
                    Button { settings.timeframe = tf } label: {
                        Text(tf.label)
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selected ? Color.accentColor : Color.primary.opacity(0.08))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 13)
        .padding(.bottom, 13)
    }

    // MARK: Watch coin

    private var watchCoinButton: some View {
        Button { showPicker = true } label: {
            Text("Watch coin")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.primary.opacity(0.22))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.bottom, 13)
    }

    // MARK: Toggles

    private var toggles: some View {
        VStack(spacing: 0) {
            row(
                title: "Draw lines",
                subtitle: "Mark price levels and alert on a cross",
                isOn: $settings.drawLines
            )
            Divider()
            row(
                title: "Show countdown in menu bar",
                subtitle: "Off shows just the icon",
                isOn: $settings.showCountdown
            )
            Divider()
            row(
                title: "Sound on close",
                subtitle: "Short beep when candle ends",
                isOn: Binding(
                    get: { settings.chimeOnClose },
                    // Preview the beep the moment it is switched on, so the
                    // setting confirms what to expect instead of staying silent
                    // until the next candle close.
                    set: { settings.chimeOnClose = $0; if $0 { Chime.play() } }
                )
            )
        }
        .padding(.horizontal, 18)
    }

    private func row(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.accentColor)
        }
        .padding(.vertical, 9)
    }

    // MARK: Quit

    private var quit: some View {
        Button { NSApplication.shared.terminate(nil) } label: {
            HStack {
                Text("Quit Kline Timer")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌘Q")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

}

extension Text {
    /// The shared uppercase micro-label used for "NEXT 5M CLOSE", "TIMEFRAME"
    /// and a coin's ticker.
    func tagStyle() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

/// One watched coin: ticker + hover-revealed trash (slides in, no layout shift,
/// reddens on its own hover) + live price, above the candle chart. The whole
/// card is the hover target, so moving from the ticker to the trash never drops
/// the hover the way a header-only region would.
private struct CoinRowView: View {
    let coin: WatchedCoin
    let drawLines: Bool
    let onRemove: () -> Void
    let onAddLevel: (Double) -> Void
    let onRemoveLevel: (PriceLevel) -> Void
    let onToggleBell: (PriceLevel) -> Void
    @State private var rowHover = false

    // Layout constants — these also derive `rowHeight`, which sizes the scroll
    // viewport, so a change here keeps the 2-row clamp in sync automatically.
    // The chart height is the same in every mode so toggling Draw lines never
    // resizes the panel mid-glance.
    private static let chartHeight: CGFloat = 120  // 1.25× the original compact height
    private static let spacing: CGFloat = 9
    private static let verticalPadding: CGFloat = 13
    private static let headerHeight: CGFloat = 14  // single-line ticker/price row
    static let rowHeight = verticalPadding + headerHeight + spacing + chartHeight + verticalPadding

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            header
            chart
        }
        .padding(.horizontal, 18)
        .padding(.vertical, Self.verticalPadding)
        .contentShape(Rectangle())
        .onHover { rowHover = $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(coin.displayName).tagStyle()
            TrashButton(visible: rowHover, action: onRemove)
            Spacer(minLength: 0)
            if let price = coin.price {
                Text(PriceFormat.string(price))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .tracking(0.6)
                    .foregroundStyle(.primary)
            } else if coin.failed {
                Text("unavailable").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var chart: some View {
        if coin.candles.isEmpty {
            Text(coin.failed ? "Couldn't load candles" : "Loading…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: Self.chartHeight, alignment: .center)
                .frame(maxWidth: .infinity)
        } else if drawLines {
            CandleChartView(candles: coin.candles, levels: coin.levels.map(\.price))
                .padding(.horizontal, PriceLevelOverlay.gutter)  // gutters hold the controls; candles sit inside
                .frame(height: Self.chartHeight)
                .overlay(
                    PriceLevelOverlay(
                        candles: coin.candles,
                        levels: coin.levels,
                        rowHover: rowHover,
                        onAdd: onAddLevel,
                        onRemove: onRemoveLevel,
                        onToggleBell: onToggleBell
                    )
                )
        } else {
            // Drawing off: the plain chart, no controls or gutters.
            CandleChartView(candles: coin.candles)
                .frame(height: Self.chartHeight)
        }
    }
}

/// A trash button that occupies its slot at all times (so revealing it never
/// reflows the row), fades + slides in when its row is hovered, and turns red
/// when hovered directly.
private struct TrashButton: View {
    let visible: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(hover ? Color.red : Color.secondary)
                .opacity(visible ? 1 : 0)
                .offset(x: visible ? 0 : 7)
                .animation(.easeOut(duration: 0.15), value: visible)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(visible)
        .onHover { hover = $0 }
        .help("Remove from watchlist")
    }
}

/// A vertical scroll container that always uses macOS overlay scrollers — thin
/// and auto-hiding — even when the user's setting is "Always show scroll bars",
/// which SwiftUI's own `ScrollView` honors with a thick legacy bar that
/// `.scrollIndicators(.hidden)` doesn't suppress.
private struct OverlayScroll<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hosting
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            hosting.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        (scrollView.documentView as? NSHostingView<Content>)?.rootView = content
    }
}
