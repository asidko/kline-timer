import SwiftUI
import KlineCore

/// The popover panel: countdown readout, timeframe picker, watched-coin charts,
/// toggles and quit.
struct PopoverView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var timer: TimerModel
    @ObservedObject var monitor: CoinMonitor

    @State private var adding = false
    @State private var draft = ""
    @State private var addFailed = false
    @State private var validating = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    private var timeString: String { CandleClock.format(secondsLeft: timer.secondsLeft) }
    private var isFinalMinute: Bool {
        CandleClock.isFinalMinute(timeframe: settings.timeframe, secondsLeft: timer.secondsLeft)
    }

    var body: some View {
        VStack(spacing: 0) {
            readout
            Divider()
            VStack(spacing: 0) {
                timeframePicker
                watchCoinControl
            }
            ForEach(monitor.coins) { coin in
                Divider()
                coinRow(coin)
            }
            Divider()
            toggles
            Divider()
            quit
        }
        .frame(width: 288)
    }

    // MARK: Readout

    private var readout: some View {
        VStack(alignment: .leading, spacing: 0) {
            tag("Next \(settings.timeframe.label) close")
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
            tag("Timeframe")
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

    @ViewBuilder private var watchCoinControl: some View {
        Group {
            if adding { addCoinField } else { addCoinButton }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 13)
    }

    private var addCoinButton: some View {
        Button { adding = true } label: {
            HStack(spacing: 6) {
                Text("+").font(.system(size: 14, weight: .semibold))
                Text("Watch coin").font(.system(size: 12.5, weight: .semibold))
            }
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
    }

    private var addCoinField: some View {
        HStack(spacing: 6) {
            TextField("Symbol, e.g. ETH", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onChange(of: draft) { _ in addFailed = false }
                .onSubmit { submitDraft() }
            if validating {
                ProgressView().controlSize(.small)
            } else {
                Button("Add") { submitDraft() }
                    .font(.system(size: 12.5, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .disabled(draft.isEmpty)
                Button { cancelAdd() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(addFailed ? Color.red.opacity(0.7) : Color.primary.opacity(0.18))
        )
    }

    private func submitDraft() {
        let symbol = draft
        guard !symbol.isEmpty, !validating else { return }
        validating = true
        addFailed = false
        Task {
            let ok = await monitor.add(symbol)
            validating = false
            if ok { cancelAdd() } else { addFailed = true }
        }
    }

    private func cancelAdd() {
        adding = false
        draft = ""
        addFailed = false
    }

    // MARK: Watched coin row

    private func coinRow(_ coin: WatchedCoin) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                tag(coin.displayName)
                Spacer(minLength: 0)
                if let price = coin.price {
                    Text(Self.formatPrice(price))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .tracking(0.6)
                        .foregroundStyle(.primary)
                } else if coin.failed {
                    Text("unavailable").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Button { monitor.remove(coin.symbol) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
            if coin.candles.isEmpty {
                Text(coin.failed ? "Couldn't load candles" : "Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 96, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                CandleChartView(candles: coin.candles)
                    .frame(height: 96)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    // MARK: Toggles

    private var toggles: some View {
        VStack(spacing: 0) {
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

    // MARK: Helpers

    /// The shared uppercase micro-label used for "NEXT 5M CLOSE", "TIMEFRAME"
    /// and a coin's ticker.
    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Group-separated price with a precision that suits the magnitude: coarse
    /// for four-figure coins, finer for sub-dollar ones.
    private static func formatPrice(_ price: Double) -> String {
        let fractionDigits: Int
        switch abs(price) {
        case 1000...: fractionDigits = 1
        case 1...: fractionDigits = 2
        case 0.01...: fractionDigits = 4
        default: fractionDigits = 6
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: price)) ?? String(price)
    }
}
